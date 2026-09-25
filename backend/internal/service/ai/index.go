package ai

import (
	"log"
	"math"
	"runtime"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"

	"monarch/internal/model"
	"monarch/internal/repository/ai_repo"
)

// vectorStaleCheck 两次"条数是否变化"检查的最小间隔。
const vectorStaleCheck = 30 * time.Second

// Index 向量与感知哈希的内存索引。
//
// 不依赖 pgvector：向量以 int8 量化形式存在 ai.embeddings，检索时把全量向量
// 载入内存做精确扫描。7w × 768 维 int8 ≈ 54MB，单次查询数十毫秒，对个人规模
// 足够快，且索引可随时丢弃重建，不引入任何外部扩展。
type Index struct {
	model string

	mu         sync.RWMutex
	ids        []uuid.UUID
	vecs       []int8
	scales     []float32
	dim        int
	loaded     bool
	lastCheck  time.Time
	phashes    map[uuid.UUID]int64
	phashReady bool
}

// NewIndex 创建索引容器（懒加载）。
func NewIndex(model string) *Index {
	return &Index{model: model, phashes: map[uuid.UUID]int64{}}
}

// VectorCount 返回当前已缓存的向量数。
func (ix *Index) VectorCount() int {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	return len(ix.ids)
}

// Loaded 报告索引是否已完成至少一次加载。
func (ix *Index) Loaded() bool {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	return ix.loaded
}

// Invalidate 丢弃缓存（下次检索时重建）。
func (ix *Index) Invalidate() {
	ix.mu.Lock()
	ix.loaded = false
	ix.phashReady = false
	ix.ids, ix.vecs, ix.scales = nil, nil, nil
	ix.mu.Unlock()
}

// EnsureLoaded 确保向量索引可用；每隔 vectorStaleCheck 抽查一次数据库条数，
// 发现变化（例如批量处理完成后）则整体重建。
func (ix *Index) EnsureLoaded() error {
	ix.mu.RLock()
	loaded := ix.loaded
	fresh := time.Since(ix.lastCheck) < vectorStaleCheck
	ix.mu.RUnlock()
	if loaded && fresh {
		return nil
	}

	if loaded {
		count, err := ai_repo.EmbeddingCount("image", ix.model)
		if err != nil {
			return err
		}
		ix.mu.Lock()
		ix.lastCheck = time.Now()
		unchanged := count == len(ix.ids)
		ix.mu.Unlock()
		if unchanged {
			return nil
		}
	}
	return ix.Reload()
}

// Reload 从数据库整体重建向量索引。
func (ix *Index) Reload() error {
	rows, err := ai_repo.LoadEmbeddings("image", ix.model)
	if err != nil {
		return err
	}

	ids := make([]uuid.UUID, 0, len(rows))
	var vecs []int8
	var scales []float32
	dim := 0

	for _, row := range rows {
		if dim == 0 {
			dim = row.Dim
		}
		if row.Dim != dim || len(row.Vec) != dim {
			continue // 跨模型的脏数据直接跳过
		}
		ids = append(ids, row.MediaID)
		vecs = append(vecs, bytesToInt8(row.Vec)...)
		scales = append(scales, row.Scale)
	}

	ix.mu.Lock()
	ix.ids, ix.vecs, ix.scales = ids, vecs, scales
	ix.dim = dim
	ix.loaded = true
	ix.lastCheck = time.Now()
	ix.mu.Unlock()

	log.Printf("[AI] 向量索引已载入: %d 条 × %d 维", len(ids), dim)
	return nil
}

// PutVector 增量写入一条向量（任务完成时调用，避免全量重建）。
func (ix *Index) PutVector(mediaID uuid.UUID, dim int, scale float32, vec []byte) {
	ix.mu.Lock()
	defer ix.mu.Unlock()

	if !ix.loaded || dim != ix.dim || len(vec) != dim {
		ix.loaded = false // 维度不一致或未加载：下次检索时重建
		return
	}
	for i, id := range ix.ids {
		if id == mediaID {
			copy(ix.vecs[i*dim:(i+1)*dim], bytesToInt8(vec))
			ix.scales[i] = scale
			return
		}
	}
	ix.ids = append(ix.ids, mediaID)
	ix.vecs = append(ix.vecs, bytesToInt8(vec)...)
	ix.scales = append(ix.scales, scale)
}

// PutPHash 增量写入感知哈希（索引尚未载入时不维护，下次分组时全量载入）。
func (ix *Index) PutPHash(mediaID uuid.UUID, hash int64) {
	ix.mu.Lock()
	defer ix.mu.Unlock()
	if !ix.phashReady {
		return
	}
	ix.phashes[mediaID] = hash
}

// SimilarHit 一条相似度命中。
type SimilarHit struct {
	MediaID uuid.UUID
	Score   float32
}

// SearchVector 用查询向量做精确余弦扫描，返回得分最高的 topK 条。
//
// allow 为 nil 时不过滤；否则仅统计 allow 返回 true 的候选。
func (ix *Index) SearchVector(query []float32, topK int, allow func(uuid.UUID) bool) ([]SimilarHit, error) {
	if err := ix.EnsureLoaded(); err != nil {
		return nil, err
	}

	ix.mu.RLock()
	ids, vecs, scales, dim := ix.ids, ix.vecs, ix.scales, ix.dim
	ix.mu.RUnlock()

	if dim == 0 || len(query) != dim || len(ids) == 0 {
		return nil, nil
	}

	scores := make([]float32, len(ids))
	parallelFor(len(ids), func(start, end int) {
		for i := start; i < end; i++ {
			base := i * dim
			var dot float32
			for j := 0; j < dim; j++ {
				dot += query[j] * float32(vecs[base+j])
			}
			scores[i] = dot * scales[i]
		}
	})

	order := make([]int, 0, len(ids))
	for i := range ids {
		if allow == nil || allow(ids[i]) {
			order = append(order, i)
		}
	}
	sort.Slice(order, func(a, b int) bool { return scores[order[a]] > scores[order[b]] })

	if topK > len(order) {
		topK = len(order)
	}
	hits := make([]SimilarHit, 0, topK)
	for _, i := range order[:topK] {
		hits = append(hits, SimilarHit{MediaID: ids[i], Score: scores[i]})
	}
	return hits, nil
}

// SimilarTo 返回与给定媒体最相似的其它媒体（以图搜图 / 相似推荐）。
func (ix *Index) SimilarTo(mediaID uuid.UUID, topK int) ([]SimilarHit, error) {
	row, err := ai_repo.GetEmbedding(mediaID, "image", ix.model)
	if err != nil {
		return nil, err
	}
	if row == nil {
		return nil, nil
	}
	query := dequantize(row, ix.dimOf())
	return ix.SearchVector(query, topK+1, func(id uuid.UUID) bool { return id != mediaID })
}

func (ix *Index) dimOf() int {
	ix.mu.RLock()
	defer ix.mu.RUnlock()
	return ix.dim
}

// EnsurePHashes 载入全部感知哈希。
func (ix *Index) EnsurePHashes() error {
	ix.mu.RLock()
	ready := ix.phashReady
	ix.mu.RUnlock()
	if ready {
		return nil
	}

	hashes, err := ai_repo.LoadPHashes()
	if err != nil {
		return err
	}
	ix.mu.Lock()
	ix.phashes = hashes
	ix.phashReady = true
	ix.mu.Unlock()
	return nil
}

// DuplicateGroups 用感知哈希找出近重复分组。
//
// 采用鸽巢原理分桶：把 64 位哈希切成 5 段，汉明距离 ≤ 4 的两张图必然有至少
// 一段完全相同，因此只需比对同段同桶的候选，避免 O(n²) 全量比较。
// 超过 4 位差异的相似图不会被此法发现（属可接受的取舍）。
func (ix *Index) DuplicateGroups(maxDistance, minGroupSize int) ([]model.DuplicateGroup, error) {
	if err := ix.EnsurePHashes(); err != nil {
		return nil, err
	}
	if maxDistance <= 0 || maxDistance > 4 {
		maxDistance = 4
	}
	if minGroupSize < 2 {
		minGroupSize = 2
	}

	ix.mu.RLock()
	hashes := make(map[uuid.UUID]int64, len(ix.phashes))
	for id, h := range ix.phashes {
		if h >= 0 { // 跳过无法解码的占位值
			hashes[id] = h
		}
	}
	ix.mu.RUnlock()

	const chunks = 5
	segmentBits := 64 / chunks // 12 位 × 4 + 16 位，末段多取
	buckets := make([]map[uint64][]uuid.UUID, chunks)
	for i := range buckets {
		buckets[i] = map[uint64][]uuid.UUID{}
	}
	for id, h := range hashes {
		for c := 0; c < chunks; c++ {
			seg := segment(h, c, segmentBits, chunks)
			buckets[c][seg] = append(buckets[c][seg], id)
		}
	}

	uf := newUnionFind()
	ids := make([]uuid.UUID, 0, len(hashes))
	for id := range hashes {
		uf.add(id)
		ids = append(ids, id)
	}

	for id := range hashes {
		seen := map[uuid.UUID]bool{}
		for c := 0; c < chunks; c++ {
			seg := segment(hashes[id], c, segmentBits, chunks)
			for _, other := range buckets[c][seg] {
				if other == id || seen[other] {
					continue
				}
				seen[other] = true
				if HammingDistance(hashes[id], hashes[other]) <= maxDistance {
					uf.union(id, other)
				}
			}
		}
	}

	// 汇总连通分量
	grouped := map[uuid.UUID][]uuid.UUID{}
	for _, id := range ids {
		root := uf.find(id)
		grouped[root] = append(grouped[root], id)
	}

	// 连通分量可能链式膨胀：A~B、B~C 但 A 与 C 相差很远（实测出现过组内最大差异
	// 14 位、成员 12 张的"重复组"）。这里把每个分量切成若干"星形"簇——簇内每张图
	// 都必须与簇代表在 maxDistance 以内，代表取邻域最大的成员。
	type groupInfo struct {
		distance int
		ids      []uuid.UUID
	}
	var groups []groupInfo
	for _, members := range grouped {
		for _, cluster := range splitByRepresentative(members, hashes, maxDistance) {
			if len(cluster) < minGroupSize {
				continue
			}
			worst := 0
			for i := 0; i < len(cluster); i++ {
				for j := i + 1; j < len(cluster); j++ {
					if d := HammingDistance(hashes[cluster[i]], hashes[cluster[j]]); d > worst {
						worst = d
					}
				}
			}
			groups = append(groups, groupInfo{distance: worst, ids: cluster})
		}
	}

	sort.Slice(groups, func(i, j int) bool { return len(groups[i].ids) > len(groups[j].ids) })

	// 附带文件名便于直接确认
	all := []uuid.UUID{}
	for _, g := range groups {
		all = append(all, g.ids...)
	}
	files := map[uuid.UUID]string{}
	if assets, err := fetchAssets(all); err == nil {
		for _, a := range assets {
			files[a.ID] = a.FilePath
		}
	}

	result := make([]model.DuplicateGroup, 0, len(groups))
	for _, g := range groups {
		names := make([]string, 0, len(g.ids))
		for _, id := range g.ids {
			names = append(names, files[id])
		}
		result = append(result, model.DuplicateGroup{
			Distance: g.distance,
			MediaIDs: g.ids,
			Files:    names,
		})
	}
	return result, nil
}

// splitByRepresentative 把一个连通分量切成若干星形簇。
//
// 代表 = 在分量内"邻居最多"的那张图（并列时取第一个）；簇 = 代表及其所有
// maxDistance 以内的成员。剩余成员递归同样处理，因此不会丢数据——只是在
// 链式膨胀时把"勉强串在一起"的图拆到各自的簇里。
func splitByRepresentative(members []uuid.UUID, hashes map[uuid.UUID]int64, maxDistance int) [][]uuid.UUID {
	if len(members) < 2 {
		return [][]uuid.UUID{members}
	}

	bestIndex := 0
	bestNeighbours := -1
	for i, candidate := range members {
		count := 0
		for j, other := range members {
			if i == j {
				continue
			}
			if HammingDistance(hashes[candidate], hashes[other]) <= maxDistance {
				count++
			}
		}
		if count > bestNeighbours {
			bestNeighbours = count
			bestIndex = i
		}
	}

	representative := members[bestIndex]
	var cluster, rest []uuid.UUID
	cluster = append(cluster, representative)
	for i, member := range members {
		if i == bestIndex {
			continue
		}
		if HammingDistance(hashes[representative], hashes[member]) <= maxDistance {
			cluster = append(cluster, member)
		} else {
			rest = append(rest, member)
		}
	}

	if len(rest) == 0 {
		return [][]uuid.UUID{cluster}
	}
	return append([][]uuid.UUID{cluster}, splitByRepresentative(rest, hashes, maxDistance)...)
}

// segment 取哈希的第 c 段（末段自动扩展到剩余位数）。
func segment(hash int64, c, segmentBits, chunks int) uint64 {
	shift := 64 - (c+1)*segmentBits
	if c == chunks-1 {
		shift = 0
	}
	mask := uint64(1)<<uint(segmentBits) - 1
	if c == chunks-1 {
		mask = uint64(1)<<uint(64-c*segmentBits) - 1
	}
	return (uint64(hash) >> uint(shift)) & mask
}

// dequantize 把 int8 量化向量还原为 float32。
func dequantize(row *ai_repo.EmbeddingRow, _ int) []float32 {
	out := make([]float32, len(row.Vec))
	for i, b := range row.Vec {
		out[i] = float32(int8(b)) * row.Scale
	}
	return out
}

func bytesToInt8(raw []byte) []int8 {
	out := make([]int8, len(raw))
	for i, b := range raw {
		out[i] = int8(b)
	}
	return out
}

// QuantizeInt8 把 float32 向量量化为 int8 并返回 (量化结果, 反量化系数)。
//
// 量化前做 L2 归一化，使内积即余弦相似度，与 Python 侧编码结果口径一致。
func QuantizeInt8(vec []float32) ([]byte, float32, []float32) {
	normalized := normalize(vec)
	var maxAbs float32
	for _, v := range normalized {
		if a := float32(math.Abs(float64(v))); a > maxAbs {
			maxAbs = a
		}
	}
	if maxAbs == 0 {
		maxAbs = 1
	}
	scale := maxAbs / 127.0

	out := make([]byte, len(normalized))
	for i, v := range normalized {
		q := int(math.Round(float64(v / scale)))
		if q > 127 {
			q = 127
		}
		if q < -127 {
			q = -127
		}
		out[i] = byte(int8(q))
	}
	return out, scale, normalized
}

// normalize 返回 L2 归一化后的副本。
func normalize(vec []float32) []float32 {
	var sum float64
	for _, v := range vec {
		sum += float64(v) * float64(v)
	}
	norm := math.Sqrt(sum)
	if norm == 0 {
		return append([]float32(nil), vec...)
	}
	out := make([]float32, len(vec))
	for i, v := range vec {
		out[i] = float32(float64(v) / norm)
	}
	return out
}

// parallelFor 把 [0,n) 切成 cpu 数个区间并行执行。
func parallelFor(n int, fn func(start, end int)) {
	workers := runtime.NumCPU()
	if workers > 8 {
		workers = 8
	}
	if n < 4096 || workers <= 1 {
		fn(0, n)
		return
	}

	chunk := (n + workers - 1) / workers
	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		start := w * chunk
		end := start + chunk
		if end > n {
			end = n
		}
		if start >= end {
			break
		}
		wg.Add(1)
		go func(s, e int) {
			defer wg.Done()
			fn(s, e)
		}(start, end)
	}
	wg.Wait()
}

// unionFind 极简并查集（用于 pHash 连通分量分组）。
type unionFind struct {
	parent map[uuid.UUID]uuid.UUID
}

func newUnionFind() *unionFind {
	return &unionFind{parent: map[uuid.UUID]uuid.UUID{}}
}

func (u *unionFind) add(id uuid.UUID) {
	if _, ok := u.parent[id]; !ok {
		u.parent[id] = id
	}
}

func (u *unionFind) find(id uuid.UUID) uuid.UUID {
	for u.parent[id] != id {
		u.parent[id] = u.parent[u.parent[id]]
		id = u.parent[id]
	}
	return id
}

func (u *unionFind) union(a, b uuid.UUID) {
	ra, rb := u.find(a), u.find(b)
	if ra != rb {
		u.parent[rb] = ra
	}
}

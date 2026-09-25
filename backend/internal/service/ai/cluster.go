package ai

import (
	"context"
	"fmt"
	"log"
	"math"
	"sort"
	"sync"

	"github.com/google/uuid"

	"monarch/internal/repository/ai_repo"
)

// DefaultFaceThreshold 人脸同人判定阈值（余弦相似度）。
// InsightFace buffalo_l 归一化特征下 0.45 是常用平衡点：过低会误并，过高会漏分。
const DefaultFaceThreshold float32 = 0.45

// MinPersonFaces 形成一个"人物分组"所需的最少人脸数。
//
// 只出现一次的人脸保持未分配：既不产生大量单人分组污染界面，
// 也能在后续出现相似人脸时被增量归入。
const MinPersonFaces = 2

// centroid 人物聚类中心（已 L2 归一化）。
type centroid struct {
	vec   []float32
	count int
}

// Clusterer 人脸聚类：以人物中心为锚做在线增量归并。
type Clusterer struct {
	model     string
	threshold float32

	mu        sync.Mutex
	centroids map[uuid.UUID]*centroid
	loaded    bool
}

// NewClusterer 创建聚类器（懒加载人物中心）。
func NewClusterer(model string) *Clusterer {
	return &Clusterer{
		model:     model,
		threshold: DefaultFaceThreshold,
		centroids: map[uuid.UUID]*centroid{},
	}
}

// Invalidate 丢弃人物中心缓存。
func (c *Clusterer) Invalidate() {
	c.mu.Lock()
	c.loaded = false
	c.centroids = map[uuid.UUID]*centroid{}
	c.mu.Unlock()
}

// EnsureLoaded 从数据库载入全部人物中心。
func (c *Clusterer) EnsureLoaded() error {
	c.mu.Lock()
	loaded := c.loaded
	c.mu.Unlock()
	if loaded {
		return nil
	}

	faces, err := ai_repo.LoadFaceEmbeddings(false)
	if err != nil {
		return err
	}

	sums := map[uuid.UUID][]float32{}
	counts := map[uuid.UUID]int{}
	for _, face := range faces {
		if face.PersonID == nil || len(face.Vector) == 0 {
			continue
		}
		vec := face.Vector
		sum := sums[*face.PersonID]
		if sum == nil {
			sum = make([]float32, len(vec))
		}
		if len(sum) != len(vec) {
			continue
		}
		for i := range vec {
			sum[i] += vec[i]
		}
		sums[*face.PersonID] = sum
		counts[*face.PersonID]++
	}

	centroids := make(map[uuid.UUID]*centroid, len(sums))
	for personID, sum := range sums {
		centroids[personID] = &centroid{vec: normalize(sum), count: counts[personID]}
	}

	c.mu.Lock()
	c.centroids = centroids
	c.loaded = true
	c.mu.Unlock()
	log.Printf("[AI] 人物中心已载入: %d 个", len(centroids))
	return nil
}

// FaceInput 一张待归并的人脸。
type FaceInput struct {
	FaceID  uuid.UUID
	MediaID uuid.UUID
	Quality float64
	Vector  []float32
}

// AssignResult 归并结果统计。
type AssignResult struct {
	Assigned  int
	NewPerson int
	Pending   int // 未匹配到任何人，保持未分配
}

// AssignIncremental 把新入库的人脸并入现有人物；匹配不到则留待聚类阶段处理。
//
// 这是处理流水线中的常规路径：只做"能否归入已有的人"，不新建分组，
// 因而不会因噪点人脸产生大量单人分组。
func (c *Clusterer) AssignIncremental(faces []FaceInput) (*AssignResult, error) {
	if len(faces) == 0 {
		return &AssignResult{}, nil
	}
	if err := c.EnsureLoaded(); err != nil {
		return nil, err
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	result := &AssignResult{}
	byPerson := map[uuid.UUID][]uuid.UUID{}

	for _, face := range faces {
		if len(face.Vector) == 0 {
			continue
		}
		vec := normalize(face.Vector)
		personID, _ := c.nearestLocked(vec)
		if personID == nil {
			result.Pending++
			continue
		}
		byPerson[*personID] = append(byPerson[*personID], face.FaceID)
		c.updateCentroidLocked(*personID, vec)
		result.Assigned++
	}

	for personID, faceIDs := range byPerson {
		if err := ai_repo.AssignFaces(faceIDs, &personID); err != nil {
			return nil, err
		}
	}
	if err := ai_repo.RefreshPersonStats(keys(byPerson)); err != nil {
		return nil, err
	}
	return result, nil
}

// ReclusterOptions 聚类参数。
type ReclusterOptions struct {
	// Reset 为 true 时清空全部已有分组重新聚类（会丢失人工命名，谨慎使用）。
	Reset bool
	// Progress 可选进度回调（已处理 / 总数）。
	Progress func(done, total int)
}

// Recluster 对"尚未分配"的人脸做批量聚类。
//
// 默认保留现有人物分组与人工命名，只处理 face.person_id IS NULL 的人脸：
// 先尝试并入现有人物，剩余部分按质量从高到低贪心成组，只有达到
// MinPersonFaces 的候选簇才落库成人物。
func (c *Clusterer) Recluster(ctx context.Context, opts ReclusterOptions) (*AssignResult, error) {
	if opts.Reset {
		if err := ai_repo.ResetAllFaceAssignments(); err != nil {
			return nil, err
		}
		c.Invalidate()
	}
	if err := c.EnsureLoaded(); err != nil {
		return nil, err
	}

	faces, err := ai_repo.LoadFaceEmbeddings(!opts.Reset)
	if err != nil {
		return nil, err
	}
	total := len(faces)
	if total == 0 {
		return &AssignResult{}, nil
	}

	// 质量高的人脸优先成组，避免低质量人脸把人拉偏
	sort.Slice(faces, func(i, j int) bool { return faces[i].Quality > faces[j].Quality })

	result := &AssignResult{}
	type candidate struct {
		vec   []float32
		faces []uuid.UUID
	}
	var candidates []*candidate

	c.mu.Lock()
	defer c.mu.Unlock()

	for i, face := range faces {
		if ctx.Err() != nil {
			return result, ctx.Err()
		}
		if opts.Progress != nil && i%200 == 0 {
			opts.Progress(i, total)
		}
		if len(face.Vector) == 0 {
			continue
		}
		vec := normalize(face.Vector)

		// 1) 先并入现有人物
		if personID, _ := c.nearestLocked(vec); personID != nil {
			if err := ai_repo.AssignFaces([]uuid.UUID{face.ID}, personID); err != nil {
				return result, err
			}
			c.updateCentroidLocked(*personID, vec)
			result.Assigned++
			continue
		}

		// 2) 再尝试并入本次已形成的候选簇
		matched := false
		for _, cand := range candidates {
			if cosine(vec, cand.vec) >= c.threshold {
				cand.faces = append(cand.faces, face.ID)
				cand.vec = mergeCentroid(cand.vec, len(cand.faces)-1, vec)
				matched = true
				break
			}
		}
		if matched {
			continue
		}

		// 3) 都不匹配：开一个新的候选簇
		candidates = append(candidates, &candidate{vec: vec, faces: []uuid.UUID{face.ID}})
	}

	// 只有达到最小规模的候选簇才成为人物分组
	for _, cand := range candidates {
		if len(cand.faces) < MinPersonFaces {
			result.Pending += len(cand.faces)
			continue
		}
		name := (*string)(nil)
		personID, err := ai_repo.CreatePerson(name)
		if err != nil {
			return result, err
		}
		if err := ai_repo.AssignFaces(cand.faces, &personID); err != nil {
			return result, err
		}
		c.centroids[personID] = &centroid{vec: cand.vec, count: len(cand.faces)}
		result.NewPerson++
		result.Assigned += len(cand.faces)
	}

	if err := ai_repo.RefreshAllPersonStats(); err != nil {
		return result, err
	}
	if dropped, err := ai_repo.DropEmptyPersons(); err == nil && dropped > 0 {
		log.Printf("[AI] 清理空人物分组: %d 个", dropped)
	}
	if opts.Progress != nil {
		opts.Progress(total, total)
	}
	return result, nil
}

// nearestLocked 返回最相似的人物 ID 及其相似度（低于阈值时 ID 为 nil）。
func (c *Clusterer) nearestLocked(vec []float32) (*uuid.UUID, float32) {
	var bestID *uuid.UUID
	var bestScore float32 = -2
	for personID, cent := range c.centroids {
		if len(cent.vec) != len(vec) {
			continue
		}
		score := cosine(vec, cent.vec)
		if score > bestScore {
			s := personID
			bestID, bestScore = &s, score
		}
	}
	if bestID == nil || bestScore < c.threshold {
		return nil, bestScore
	}
	return bestID, bestScore
}

// updateCentroidLocked 用一个新人脸更新人物中心（在线平均）。
func (c *Clusterer) updateCentroidLocked(personID uuid.UUID, vec []float32) {
	cent, ok := c.centroids[personID]
	if !ok || len(cent.vec) != len(vec) {
		c.centroids[personID] = &centroid{vec: vec, count: 1}
		return
	}
	merged := make([]float32, len(vec))
	n := float32(cent.count)
	for i := range vec {
		merged[i] = (cent.vec[i]*n + vec[i]) / (n + 1)
	}
	cent.vec = normalize(merged)
	cent.count++
}

// mergeCentroid 按既有成员数把新向量并入候选簇中心。
func mergeCentroid(current []float32, existing int, vec []float32) []float32 {
	if len(current) != len(vec) {
		return current
	}
	merged := make([]float32, len(vec))
	n := float32(existing)
	for i := range vec {
		merged[i] = (current[i]*n + vec[i]) / (n + 1)
	}
	return normalize(merged)
}

// cosine 计算两个 L2 归一化向量的余弦相似度。
func cosine(a, b []float32) float32 {
	if len(a) != len(b) {
		return -1
	}
	var dot float32
	for i := range a {
		dot += a[i] * b[i]
	}
	return dot
}

func keys(m map[uuid.UUID][]uuid.UUID) []uuid.UUID {
	out := make([]uuid.UUID, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

// ClusterState 聚类器状态快照。
type ClusterState struct {
	Persons     int     `json:"persons"`
	Threshold   float32 `json:"threshold"`
	MinGroup    int     `json:"min_group_faces"`
	CentroidsOK bool    `json:"centroids_loaded"`
}

// State 返回聚类器状态。
func (c *Clusterer) State() ClusterState {
	c.mu.Lock()
	defer c.mu.Unlock()
	return ClusterState{
		Persons:     len(c.centroids),
		Threshold:   c.threshold,
		MinGroup:    MinPersonFaces,
		CentroidsOK: c.loaded,
	}
}

// SetThreshold 调整同人判定阈值（0.2 ~ 0.8）。
func (c *Clusterer) SetThreshold(value float32) error {
	if value < 0.2 || value > 0.8 {
		return fmt.Errorf("阈值需在 0.2 ~ 0.8 之间")
	}
	c.mu.Lock()
	c.threshold = value
	c.mu.Unlock()
	return nil
}

// faceQuality 由检测分与人脸面积估算质量（用于挑选人物封面与聚类顺序）。
func faceQuality(detScore float64, box []float32) float64 {
	if len(box) < 4 {
		return detScore
	}
	w := math.Abs(float64(box[2] - box[0]))
	h := math.Abs(float64(box[3] - box[1]))
	area := math.Sqrt(w * h) // 归一化面积的平方根 ≈ 人脸边长
	return detScore * math.Min(1, area*2)
}

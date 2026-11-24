package ai

import (
	"bytes"
	"context"
	"math"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"

	"monarch/internal/repository/ai_repo"
)

const (
	DefaultFaceThreshold float32 = 0.45
	MinPersonFaces               = 2
	faceMatchMargin      float32 = 0.04
)

type centroid struct {
	sum   []float32
	norm  float32
	media map[uuid.UUID]struct{}
}

func (c *centroid) add(face ai_repo.FaceEmbedding) {
	if c.sum == nil {
		c.sum = make([]float32, len(face.Vector))
		c.media = make(map[uuid.UUID]struct{})
	}
	if len(face.Vector) != len(c.sum) {
		return
	}
	weight := float32(max(0.2, min(face.Quality, 1)))
	var squared float64
	for i, value := range face.Vector {
		c.sum[i] += value * weight
		squared += float64(c.sum[i]) * float64(c.sum[i])
	}
	c.norm = float32(math.Sqrt(squared))
	c.media[face.MediaID] = struct{}{}
}

type Clusterer struct {
	mu        sync.Mutex
	centroids map[uuid.UUID]*centroid
	lastUsed  time.Time
}

func NewClusterer() *Clusterer { return &Clusterer{} }

func (c *Clusterer) Invalidate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.centroids = nil
}

func (c *Clusterer) ReleaseIdle(timeout time.Duration) bool {
	if !c.mu.TryLock() {
		return false
	}
	defer c.mu.Unlock()
	if c.centroids == nil || time.Since(c.lastUsed) < timeout {
		return false
	}
	c.centroids = nil
	return true
}

func (c *Clusterer) loadLocked(ctx context.Context) error {
	if c.centroids != nil {
		return nil
	}
	faces, err := ai_repo.LoadFaceEmbeddings(ctx, new(true))
	if err != nil {
		return err
	}
	c.centroids = make(map[uuid.UUID]*centroid)
	for _, face := range faces {
		person := *face.PersonID
		if c.centroids[person] == nil {
			c.centroids[person] = &centroid{}
		}
		c.centroids[person].add(face)
	}
	return nil
}

type AssignResult struct {
	Assigned  int
	NewPerson int
	Pending   int
}

func (c *Clusterer) AssignIncremental(ctx context.Context, faces []ai_repo.FaceEmbedding) error {
	if len(faces) == 0 {
		return nil
	}
	_, err := c.placeFaces(ctx, faces, nil)
	return err
}

func (c *Clusterer) Recluster(ctx context.Context, reset bool) (*AssignResult, error) {
	return c.placeFaces(ctx, nil, &reset)
}

func (c *Clusterer) placeFaces(ctx context.Context, faces []ai_repo.FaceEmbedding, resetGroups *bool) (_ *AssignResult, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	defer func() {
		c.lastUsed = time.Now()
		if err != nil {
			c.centroids = nil
		}
	}()

	reset := resetGroups != nil && *resetGroups
	if reset {
		c.centroids = make(map[uuid.UUID]*centroid)
	} else if err := c.loadLocked(ctx); err != nil {
		return nil, err
	}
	if resetGroups != nil {
		var assigned *bool
		if !reset {
			assigned = new(false)
		}
		faces, err = ai_repo.LoadFaceEmbeddings(ctx, assigned)
		if err != nil {
			return nil, err
		}
	}
	sort.Slice(faces, func(i, j int) bool {
		if faces[i].Quality == faces[j].Quality {
			return bytes.Compare(faces[i].ID[:], faces[j].ID[:]) < 0
		}
		return faces[i].Quality > faces[j].Quality
	})

	byPerson := make(map[uuid.UUID][]uuid.UUID)
	candidates := make(map[uuid.UUID]*centroid)
	byCandidate := make(map[uuid.UUID][]uuid.UUID)
	result := &AssignResult{}
	for _, face := range faces {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		person, score := nearestFace(face, c.centroids)
		if person != uuid.Nil {
			c.centroids[person].add(face)
			byPerson[person] = append(byPerson[person], face.ID)
			result.Assigned++
			continue
		}
		if resetGroups == nil || score >= DefaultFaceThreshold {
			result.Pending++
			continue
		}
		candidate, _ := nearestFace(face, candidates)
		if candidate == uuid.Nil {
			candidate = face.ID
			candidates[candidate] = &centroid{}
		}
		candidates[candidate].add(face)
		byCandidate[candidate] = append(byCandidate[candidate], face.ID)
	}

	groups := make([]ai_repo.FaceGroup, 0, len(byPerson))
	for id, ids := range byPerson {
		groups = append(groups, ai_repo.FaceGroup{PersonID: id, FaceIDs: ids})
	}
	for candidate, ids := range byCandidate {
		if len(ids) < MinPersonFaces {
			result.Pending += len(ids)
			continue
		}
		person := uuid.New()
		groups = append(groups, ai_repo.FaceGroup{PersonID: person, FaceIDs: ids, New: true})
		c.centroids[person] = candidates[candidate]
		result.NewPerson++
		result.Assigned += len(ids)
	}
	if err := ai_repo.ApplyFaceGroups(ctx, groups, reset); err != nil {
		return nil, err
	}
	return result, nil
}

func nearestFace(face ai_repo.FaceEmbedding, centers map[uuid.UUID]*centroid) (uuid.UUID, float32) {
	best, second := float32(-1), float32(-1)
	var winner uuid.UUID
	for id, center := range centers {
		if _, occupied := center.media[face.MediaID]; occupied || center.norm == 0 {
			continue
		}
		if len(center.sum) != len(face.Vector) {
			continue
		}
		score := cosine(face.Vector, center.sum) / center.norm
		if score > best {
			second, best, winner = best, score, id
		} else if score > second {
			second = score
		}
	}
	if best < DefaultFaceThreshold || best-second < faceMatchMargin {
		return uuid.Nil, best
	}
	return winner, best
}

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

type ClusterState struct {
	Persons     int     `json:"persons"`
	Threshold   float32 `json:"threshold"`
	MinGroup    int     `json:"min_group_faces"`
	CentroidsOK bool    `json:"centroids_loaded"`
}

func (c *Clusterer) State() ClusterState {
	c.mu.Lock()
	defer c.mu.Unlock()
	return ClusterState{
		Persons: len(c.centroids), Threshold: DefaultFaceThreshold,
		MinGroup: MinPersonFaces, CentroidsOK: c.centroids != nil,
	}
}

// faceQuality 由检测分与人脸大小估算质量。
func faceQuality(detScore float64, box []float32) float64 {
	if len(box) < 4 {
		return detScore
	}
	w := math.Abs(float64(box[2] - box[0]))
	h := math.Abs(float64(box[3] - box[1]))
	return detScore * math.Min(1, math.Sqrt(w*h)*2)
}

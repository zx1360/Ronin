package repository_test

import (
	"encoding/json"
	"errors"
	"os"
	"reflect"
	"testing"
	"time"

	"monarch/internal/model"
	"monarch/internal/repository/data_repo"
	"monarch/internal/service/db"
)

func TestUserDataContract(t *testing.T) {
	raw, err := os.ReadFile("../../../contracts/user_data.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		ID    string `json:"id"`
		Cases []struct {
			Name     string             `json:"name"`
			Server   data_repo.SyncData `json:"server"`
			Client   data_repo.SyncData `json:"client"`
			Expected *model.EssayLabel  `json:"expected"`
		} `json:"merge_cases"`
		Calendar []string `json:"calendar_dates"`
		Instants []string `json:"instants"`
	}
	if err := json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	clear := func() {
		t.Helper()
		ctx, cancel := db.GetDefaultCtx()
		defer cancel()
		for _, query := range []string{"DELETE FROM essay_labels WHERE id=?", "DELETE FROM user_data_changes WHERE row_id=?"} {
			if _, err := db.Exec(ctx, query, fixture.ID); err != nil {
				t.Fatal(err)
			}
		}
	}
	t.Cleanup(clear)
	for _, tc := range fixture.Cases {
		t.Run(tc.Name, func(t *testing.T) {
			clear()
			for _, data := range []data_repo.SyncData{tc.Server, tc.Client} {
				if err := data_repo.MergeSync("essay", data); err != nil {
					t.Fatal(err)
				}
			}
			result, err := data_repo.ReadSync("essay", 0)
			if err != nil {
				t.Fatal(err)
			}
			var found map[string]any
			for _, row := range result["labels"].([]map[string]any) {
				if row["id"] == fixture.ID {
					found = row
				}
			}
			if tc.Expected == nil {
				if found != nil {
					t.Fatal("删除标记未生效")
				}
			} else if found == nil || found["name"] != tc.Expected.Name || !found["updated_at"].(model.FlexTime).Time().Equal(tc.Expected.UpdatedAt.Time()) {
				t.Fatalf("合并结果不符: %v", found)
			}
			cursor := result["cursor"].(int64)
			if err := data_repo.MergeSync("essay", tc.Client); err != nil {
				t.Fatal(err)
			}
			repeated, err := data_repo.ReadSync("essay", cursor)
			if err != nil || repeated["cursor"] != cursor {
				t.Fatalf("重复提交推进了游标: %v / %v", repeated, err)
			}
			if _, err := data_repo.ReadSync("essay", cursor+1); !errors.Is(err, data_repo.ErrInvalidSyncCursor) {
				t.Fatal("无效游标未拒绝")
			}
		})
	}
	t.Run("整批失败回滚", func(t *testing.T) {
		clear()
		before, err := data_repo.ReadSync("essay", 0)
		if err != nil {
			t.Fatal(err)
		}
		valid := fixture.Cases[0].Client.Labels[0]
		invalid := valid
		invalid.ID[15]++
		invalid.Name = ""
		err = data_repo.MergeSync("essay", data_repo.SyncData{SyncVersion: 2, Labels: []model.EssayLabel{valid, invalid}})
		if err == nil {
			t.Fatal("无效批次未拒绝")
		}
		after, err := data_repo.ReadSync("essay", 0)
		if err != nil || !reflect.DeepEqual(before, after) {
			t.Fatal("无效批次部分提交了数据或游标")
		}
	})
	for _, text := range append(fixture.Calendar, fixture.Instants...) {
		var value model.FlexTime
		encoded, _ := json.Marshal(text)
		if err := json.Unmarshal(encoded, &value); err != nil {
			t.Fatal(err)
		}
		encoded, _ = json.Marshal(value)
		var roundtrip model.FlexTime
		if err := json.Unmarshal(encoded, &roundtrip); err != nil || !roundtrip.Time().Equal(value.Time()) {
			t.Fatalf("时间往返失真: %s", text)
		}
	}
	for _, text := range fixture.Calendar {
		var value model.FlexTime
		encoded, _ := json.Marshal(text)
		_ = json.Unmarshal(encoded, &value)
		if value.Time().UTC().Format(time.DateOnly) != text[:10] {
			t.Fatalf("日历日漂移: %s", text)
		}
	}
}

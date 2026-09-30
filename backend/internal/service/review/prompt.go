package review

import (
	"fmt"
	"strings"
)

// 输出约束固定下发：模型只能围绕给定统计与素材写，避免编造数字或写成流水账。
const writingRules = `写作要求：
- 只依据下面给出的统计与材料，不要编造未出现的人、事、数字；材料太少就直接说这段时间记录不多。
- 用第二人称"你"来写，像在对我说话；不要写成报告、清单或条目罗列。
- 具体优先：多引用材料里的细节与措辞，少用"你很努力""继续加油"这类空话。
- 直接给正文，不要标题、不要 markdown 标记、不要在结尾提问。`

// Prompts 组装 (system, user) 两段提示词：角色与语气来自用户预设。
func Prompts(role, tone, focus string, data *Data) (string, string) {
	var system strings.Builder
	system.WriteString(strings.TrimSpace(role))
	if tone = strings.TrimSpace(tone); tone != "" {
		system.WriteString("\n\n语气要求：\n")
		system.WriteString(tone)
	}
	system.WriteString("\n\n")
	system.WriteString(writingRules)

	var user strings.Builder
	user.WriteString(data.Stats.Text())
	writeEssaySamples(&user, data.Essays)
	writeRecordSamples(&user, data.Records)
	if focus = strings.TrimSpace(focus); focus != "" {
		user.WriteString("\n\n【这次特别想聊的】\n")
		user.WriteString(focus)
	}
	return system.String(), user.String()
}

// Text 把统计渲染成紧凑文本：既是提示词的一部分，也直接下发给端上展示"本次依据"。
func (s Stats) Text() string {
	var b strings.Builder
	fmt.Fprintf(&b, "统计范围：%s ~ %s（%d 天）\n", s.From, s.To, s.Days)

	b.WriteString("【随笔】")
	if s.Essay.Count == 0 {
		b.WriteString("这段时间没有写\n")
	} else {
		fmt.Fprintf(&b, "共 %d 篇，合计 %d 字；有写作的天数 %d 天，最长连续 %d 天\n",
			s.Essay.Count, s.Essay.WordCount, s.Essay.ActiveDays, s.Essay.LongestStreak)
		if s.Essay.LongestWords > 0 {
			fmt.Fprintf(&b, "  - 最长的一篇：%s，%d 字\n", s.Essay.LongestDate, s.Essay.LongestWords)
		}
		writeCounts(&b, "  - 常用标签：", s.Essay.TopLabels)
		writeCounts(&b, "  - 心情分布：", s.Essay.Moods)
	}

	b.WriteString("【打卡】")
	if s.Booklet.RecordCount == 0 {
		b.WriteString("这段时间没有打卡记录\n")
	} else {
		fmt.Fprintf(&b, "共 %d 条记录，打卡 %d 天，其中全勤 %d 天，最长连续 %d 天；%d 天写了留言\n",
			s.Booklet.RecordCount, s.Booklet.ActiveDays, s.Booklet.FullyDoneDays,
			s.Booklet.LongestStreak, s.Booklet.MessageDays)
		writeCounts(&b, "  - 心情分布：", s.Booklet.Moods)
		for _, group := range s.Booklet.Groups {
			name := strings.Join(group.Tasks, "/")
			if name == "" {
				name = "（已删除的任务组）"
			}
			fmt.Fprintf(&b, "  - 任务组「%s」：%d 条，全勤 %d 天，完成率 %.0f%%\n",
				name, group.RecordCount, group.FullyDoneDays, group.DoneRate*100)
		}
	}
	return strings.TrimRight(b.String(), "\n")
}

func writeCounts(b *strings.Builder, prefix string, items []Count) {
	if len(items) == 0 {
		return
	}
	parts := make([]string, 0, len(items))
	for _, item := range items {
		parts = append(parts, fmt.Sprintf("%s %d", item.Name, item.Count))
	}
	b.WriteString(prefix)
	b.WriteString(strings.Join(parts, "、"))
	b.WriteString("\n")
}

func writeEssaySamples(b *strings.Builder, samples []EssaySample) {
	if len(samples) == 0 {
		return
	}
	b.WriteString("\n【随机抽取的随笔】\n")
	for _, item := range samples {
		meta := []string{fmt.Sprintf("%d 字", item.WordCount)}
		if len(item.Labels) > 0 {
			meta = append(meta, "标签："+strings.Join(item.Labels, "、"))
		}
		if item.Mood != "" {
			meta = append(meta, "心情："+item.Mood)
		}
		fmt.Fprintf(b, "- %s（%s）\n%s\n", item.Date, strings.Join(meta, "；"), item.Content)
	}
}

func writeRecordSamples(b *strings.Builder, samples []RecordSample) {
	if len(samples) == 0 {
		return
	}
	b.WriteString("\n【随机抽取的打卡记录】\n")
	for _, item := range samples {
		line := fmt.Sprintf("- %s", item.Date)
		if item.Group != "" {
			line += "（" + item.Group + "）"
		}
		if len(item.Done) > 0 {
			line += "：完成 " + strings.Join(item.Done, "、")
		}
		if len(item.Missed) > 0 {
			line += "；未完成 " + strings.Join(item.Missed, "、")
		}
		if item.Mood != "" {
			line += "；心情 " + item.Mood
		}
		b.WriteString(line)
		b.WriteString("\n")
		if item.Message != "" {
			fmt.Fprintf(b, "  留言：%s\n", item.Message)
		}
	}
}

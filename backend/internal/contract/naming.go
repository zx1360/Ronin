package contract

import (
	"strings"
	"unicode"
)

// splitWords 把 Go 风格标识符切成词，便于转成客户端命名：
// "MediaID" -> [Media ID]，"OCRText" -> [OCR Text]，"PHash" -> [PHash]。
func splitWords(s string) []string {
	runes := []rune(s)
	if len(runes) == 0 {
		return nil
	}
	words := make([]string, 0, 4)
	start := 0
	for i := 1; i < len(runes); i++ {
		if !unicode.IsUpper(runes[i]) {
			continue
		}
		prevLower := unicode.IsLower(runes[i-1]) || unicode.IsDigit(runes[i-1])
		nextLower := i+1 < len(runes) && unicode.IsLower(runes[i+1])
		if prevLower || (nextLower && i-1 > start) {
			words = append(words, string(runes[start:i]))
			start = i
		}
	}
	return append(words, string(runes[start:]))
}

// titleWord 把整词小写后首字母大写："IDs" -> "Ids"，"OCR" -> "Ocr"。
func titleWord(word string) string {
	if word == "" {
		return word
	}
	runes := []rune(strings.ToLower(word))
	runes[0] = unicode.ToUpper(runes[0])
	return string(runes)
}

// upperFirst 只把首字母大写，保留词内既有大小写："chapterInfo" -> "ChapterInfo"。
func upperFirst(s string) string {
	if s == "" {
		return s
	}
	runes := []rune(s)
	runes[0] = unicode.ToUpper(runes[0])
	return string(runes)
}

// lowerCamel 把 Go 标识符转成 lowerCamelCase："MediaID" -> "mediaId"。
func lowerCamel(s string) string {
	words := splitWords(s)
	var b strings.Builder
	for i, word := range words {
		if word == "" {
			continue
		}
		if b.Len() == 0 || i == 0 {
			b.WriteString(strings.ToLower(word))
			continue
		}
		b.WriteString(titleWord(word))
	}
	return b.String()
}

// camelSegment 把路径片段转成 camelCase："comic-info" -> "comicInfo"。
func camelSegment(s string) string {
	parts := strings.FieldsFunc(s, func(r rune) bool {
		return r == '-' || r == '_' || r == '.' || r == ' ' || r == '/'
	})
	var b strings.Builder
	for _, part := range parts {
		if part == "" {
			continue
		}
		if b.Len() == 0 {
			b.WriteString(lowerCamel(part))
			continue
		}
		b.WriteString(upperFirst(lowerCamel(part)))
	}
	return b.String()
}

// camelJoin 拼接已 camelCase 的片段："gallery" + "media" -> "galleryMedia"。
func camelJoin(segments []string) string {
	var b strings.Builder
	for _, segment := range segments {
		if segment == "" {
			continue
		}
		if b.Len() == 0 {
			b.WriteString(segment)
			continue
		}
		b.WriteString(upperFirst(segment))
	}
	return b.String()
}

// methodSuffix 把 HTTP 方法转成标识符后缀："PATCH" -> "Patch"。
func methodSuffix(method string) string {
	return titleWord(strings.ToLower(strings.TrimSpace(method)))
}

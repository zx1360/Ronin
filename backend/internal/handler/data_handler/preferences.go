package data_handler

import (
	"encoding/json"
	"fmt"
	"path"
	"path/filepath"
	"strings"
)

func preferenceImages(raw json.RawMessage) (map[string]bool, error) {
	var prefs map[string]json.RawMessage
	if err := json.Unmarshal(raw, &prefs); err != nil || prefs == nil {
		return nil, fmt.Errorf("缺少有效的 preferences 对象")
	}
	refs, paths := map[string]bool{}, map[string]string{}
	add := func(image, dir string) error {
		if image == "" {
			return nil
		}
		image = strings.TrimPrefix(image, "/")
		name := path.Base(image)
		if image != "preferences/"+dir+"/"+name || !filepath.IsLocal(name) || name == "." || strings.ContainsAny(image, "\\") {
			return fmt.Errorf("无效的偏好图片路径: %s", image)
		}
		if previous, exists := paths[name]; exists && previous != image {
			return fmt.Errorf("偏好图片文件名重复: %s", name)
		}
		paths[name], refs[name] = image, true
		return nil
	}
	for _, field := range []string{"backgroundImages", "sidebarImages", "mottos"} {
		var values []any
		if err := json.Unmarshal(prefs[field], &values); err != nil || values == nil {
			return nil, fmt.Errorf("偏好 %s 必须为文本数组", field)
		}
		dir := "background"
		if field == "sidebarImages" {
			dir = "sidebar"
		}
		for _, item := range values {
			image, ok := item.(string)
			if !ok {
				return nil, fmt.Errorf("偏好 %s 必须为文本数组", field)
			}
			if field == "mottos" {
				continue
			}
			if err := add(image, dir); err != nil {
				return nil, err
			}
		}
	}
	for _, field := range []string{"nickname", "signature", "avatarPath"} {
		if field == "avatarPath" && string(prefs[field]) == "null" {
			continue
		}
		var value string
		if len(prefs[field]) == 0 || string(prefs[field]) == "null" || json.Unmarshal(prefs[field], &value) != nil {
			return nil, fmt.Errorf("偏好 %s 必须为文本", field)
		}
		if field == "avatarPath" {
			if err := add(value, "avatar"); err != nil {
				return nil, err
			}
		}
	}
	if raw, exists := prefs["networkConfig"]; exists {
		var network struct {
			APIKey      *string `json:"apiKey"`
			HostList    *string `json:"hostList"`
			ActiveIndex *int    `json:"activeIndex"`
		}
		if json.Unmarshal(raw, &network) != nil || network.APIKey == nil || network.HostList == nil || network.ActiveIndex == nil {
			return nil, fmt.Errorf("偏好的网络配置无效")
		}
		hosts := []struct{ Host, Port *string }{}
		if *network.HostList != "" && (json.Unmarshal([]byte(*network.HostList), &hosts) != nil || hosts == nil) {
			return nil, fmt.Errorf("偏好的主机列表无效")
		}
		index := *network.ActiveIndex
		if index < 0 || (len(hosts) == 0 && index != 0) || (len(hosts) > 0 && index >= len(hosts)) {
			return nil, fmt.Errorf("偏好的激活下标无效")
		}
		for _, host := range hosts {
			if host.Host == nil || host.Port == nil {
				return nil, fmt.Errorf("偏好的主机配置无效")
			}
		}
	}
	return refs, nil
}

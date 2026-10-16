import { h } from '../../vue.js';
import { imageUrl } from '../user-data.js';

function safeLink(raw) {
  try {
    const url = new URL(raw, window.location.origin);
    return ['https:', 'http:'].includes(url.protocol) ? url.href : '';
  } catch { return ''; }
}

function inline(text) {
  const tokens = /(!?\[[^\]]*\]\([^\s)]+\)|\*\*[^*]+\*\*|`[^`]+`|\*[^*\n]+\*)/g;
  const nodes = [];
  let end = 0;
  for (const match of text.matchAll(tokens)) {
    nodes.push(text.slice(end, match.index));
    const token = match[0];
    if (token.startsWith('**')) nodes.push(h('strong', token.slice(2, -2)));
    else if (token.startsWith('`')) nodes.push(h('code', token.slice(1, -1)));
    else if (token.startsWith('*')) nodes.push(h('em', token.slice(1, -1)));
    else {
      const link = token.match(/^(!?)\[([^\]]*)\]\(([^)]+)\)$/);
      if (link[1]) {
        const path = link[3].replace(/^\/?(?:static\/)?/, '');
        const src = imageUrl(path);
        nodes.push(src ? h('img', { src, alt: link[2], loading: 'lazy' }) : token);
      } else {
        const href = safeLink(link[3]);
        nodes.push(href ? h('a', { href, target: '_blank', rel: 'noopener noreferrer' }, link[2]) : token);
      }
    }
    end = match.index + token.length;
  }
  nodes.push(text.slice(end));
  return nodes;
}

export default {
  props: { text: { default: '' } },
  setup(props) {
    return () => {
      const nodes = [], lines = props.text.replaceAll('\r', '').split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.startsWith('```')) {
          const code = [];
          while (++i < lines.length && !lines[i].startsWith('```')) code.push(lines[i]);
          nodes.push(h('pre', [h('code', code.join('\n'))]));
        } else if (/^#{1,6} /.test(line)) {
          const heading = line.match(/^(#{1,6}) (.*)$/);
          nodes.push(h(`h${heading[1].length}`, inline(heading[2])));
        } else if (/^([-*_])\1{2,}$/.test(line.trim())) nodes.push(h('hr'));
        else if (/^> ?/.test(line)) nodes.push(h('blockquote', inline(line.replace(/^> ?/, ''))));
        else if (/^\s*(?:[-*+] |\d+\. )/.test(line)) {
          const ordered = /^\s*\d+\. /.test(line), items = [];
          const pattern = ordered ? /^\s*\d+\. / : /^\s*[-*+] /;
          while (i < lines.length && pattern.test(lines[i])) { items.push(h('li', inline(lines[i].replace(pattern, '')))); i++; }
          i--; nodes.push(h(ordered ? 'ol' : 'ul', items));
        } else if (line.trim()) {
          const paragraph = [line];
          while (i + 1 < lines.length && lines[i + 1].trim() && !/^(?:#{1,6} |>|```|[-*+] |\d+\. )/.test(lines[i + 1])) paragraph.push(lines[++i]);
          nodes.push(h('p', inline(paragraph.join('\n'))));
        }
      }
      return h('div', { class: 'user-markdown' }, nodes);
    };
  },
};

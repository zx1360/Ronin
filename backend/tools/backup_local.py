"""停服后备份数据库、个人附件及配置；Gallery/Comic 原始文件需另行备份。"""
import argparse
from contextlib import closing
from datetime import datetime
import json
from pathlib import Path
import shutil
import sqlite3
import uuid

from dotenv import dotenv_values


def backup(db: Path, data: Path, output: Path, env_file: Path) -> None:
    db, data, output = db.resolve(), data.resolve(), output.resolve()
    if output.exists() or output.is_relative_to(data) or output == db:
        raise ValueError('备份目标必须是数据目录之外的新目录')
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = output.with_name(output.name + '.partial-' + uuid.uuid4().hex)
    try:
        with closing(sqlite3.connect(db.as_uri() + '?mode=rw', uri=True, timeout=1)) as source:
            # 独占锁保留到连接关闭，避免数据库与附件在备份期间被服务改写。
            source.execute('PRAGMA locking_mode=EXCLUSIVE')
            source.execute('BEGIN EXCLUSIVE')
            source.rollback()
            staged.mkdir()
            (staged / '.gitignore').write_text('*\n', encoding='utf-8')
            with closing(sqlite3.connect(staged / 'monarch.db')) as target:
                source.backup(target)
                if target.execute('PRAGMA quick_check').fetchall() != [('ok',)]:
                    raise RuntimeError('备份数据库校验失败')
            for module in ('essay', 'booklet', 'preferences'):
                relative = Path('img_storage') / module
                if (data / relative).is_dir():
                    shutil.copytree(data / relative, staged / relative)
            for name in ('ai_config.json', 'ops_web.json', 'review_presets.json',
                         'preferences/preferences.json'):
                path = data / name
                if path.is_file():
                    dest = staged / (name if '/' in name else f'data/{name}')
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, dest)
            for name in ('server.crt', 'server.key'):
                path = env_file.parent / 'cert' / name
                if path.is_file():
                    (staged / 'cert').mkdir(exist_ok=True)
                    shutil.copy2(path, staged / 'cert' / name)
            if env_file.is_file():
                shutil.copy2(env_file, staged / 'backend.env')
            (staged / 'manifest.json').write_text(json.dumps({
                'format_version': 1, 'created_at': datetime.now().astimezone().isoformat(),
                'source_db': str(db), 'source_data': str(data),
                'sqlite_version': sqlite3.sqlite_version,
                'excluded': ['Gallery/Comic 原始文件', 'Android/浏览器本机数据'],
            }, ensure_ascii=False, indent=2), encoding='utf-8')
        staged.rename(output)
    finally:
        if staged.is_dir() and staged.parent == output.parent:
            shutil.rmtree(staged)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--db', type=Path)
    parser.add_argument('--data', type=Path)
    args = parser.parse_args()
    env_file = root / '.env'
    env = dotenv_values(env_file)
    try:
        backup(root / (args.db or env.get('DB_FILE') or 'data/monarch.db'),
               root / (args.data or env.get('DATA_DIR') or 'data'), args.output, env_file)
    except (OSError, ValueError, sqlite3.Error, RuntimeError) as error:
        parser.exit(1, f'备份未完成（请先停止 Monarch 和所有 CLI）：{error}\n')
    print(f'备份已校验：{args.output.resolve()}')


if __name__ == '__main__':
    main()

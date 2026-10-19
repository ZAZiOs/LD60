#!/usr/bin/env python3
"""
scripts/build_web.py
Скрипт для сборки веб-версии (HTML5 / WebAssembly) игры Love2D.
1. Упаковывает main.lua, conf.lua, src/, assets/ в .love архив (game.data).
2. Обновляет game.js с новым package_uuid и точным размером пакета.
3. Обновляет index.html с защитой от агрессивного браузерного кеширования (?ts=...).
4. Опционально запускает локальный no-cache веб-сервер для тестирования (--serve).
"""

import os
import sys
import uuid
import time
import zipfile
import re
import argparse
from pathlib import Path

if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

def build_love_archive(root_dir: Path, output_path: Path):
    """Упаковывает файлы игры в .love ZIP архив."""
    print(f"[1/3] Packing game files into {output_path.name}...")
    
    ignore_patterns = {
        '.git', '.vscode', '.idea', '__pycache__', 'web-build', 'scripts',
        '*.love', 'test_runner.lua', '.DS_Store', 'Thumbs.db'
    }
    
    with zipfile.ZipFile(output_path, 'w', compression=zipfile.ZIP_DEFLATED) as zip_file:
        # 1. Корневые файлы
        for root_file in ['main.lua', 'conf.lua']:
            fp = root_dir / root_file
            if fp.exists():
                zip_file.write(fp, arcname=root_file)
                print(f"  + {root_file}")
            else:
                print(f"  ! Warning: {root_file} not found!")

        # Маркер веб-версии
        zip_file.writestr("web_build.flag", "1")

        # 2. Папки src и assets
        for folder in ['src', 'assets']:
            folder_path = root_dir / folder
            if not folder_path.exists():
                continue
            for root, dirs, files in os.walk(folder_path):
                # Исключаем временные файлы
                dirs[:] = [d for d in dirs if not d.startswith('.')]
                for file in files:
                    if file.startswith('.') or file.endswith(('.tmp', '.bak')):
                        continue
                    full_path = Path(root) / file
                    rel_path = full_path.relative_to(root_dir)
                    zip_file.write(full_path, arcname=str(rel_path).replace('\\', '/'))
    
    file_size = output_path.stat().st_size
    print(f"  ✓ Packed successfully: {file_size:,} bytes")
    return file_size

def update_game_js(web_dir: Path, file_size: int, package_uuid: str):
    """Обновляет game.js с новым размером и UUID пакета."""
    print(f"[2/3] Updating game.js with size={file_size} and UUID={package_uuid}...")
    game_js_path = web_dir / "game.js"
    
    if not game_js_path.exists():
        print("  ! Warning: web-build/game.js not found!")
        return

    content = game_js_path.read_text(encoding="utf-8")
    
    # Заменяем вызов loadPackage({"package_uuid": ...}) в конце файла
    pattern = r'loadPackage\(\s*\{.*?\}\s*\);'
    new_payload = f'loadPackage({{"package_uuid":"{package_uuid}","remote_package_size":{file_size},"files":[{{"filename":"/game.love","crunched":0,"start":0,"end":{file_size},"audio":false}}]}});'
    
    if re.search(pattern, content):
        content = re.sub(pattern, new_payload, content)
    else:
        content = content.rstrip() + f'\n  {new_payload}\n}})();\n'
        
    game_js_path.write_text(content, encoding="utf-8")
    print("  ✓ game.js updated successfully")

def update_index_html(web_dir: Path, build_ts: int):
    """Обновляет index.html с мета-тегами против кеширования и динамической загрузкой ассетов с ?ts=."""
    print(f"[3/3] Updating index.html with anti-cache timestamp ts={build_ts}...")
    index_html_path = web_dir / "index.html"
    
    html_content = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no, minimum-scale=1, maximum-scale=1">
    <title>tech_plague</title>

    <script src="coi-serviceworker.js"></script>
    <script type="text/javascript">
      var BUILD_TS = {build_ts};
      var tsLink = document.createElement('link');
      tsLink.rel = 'stylesheet';
      tsLink.type = 'text/css';
      tsLink.href = 'theme/love.css?ts=' + BUILD_TS;
      document.head.appendChild(tsLink);
    </script>
  </head>
  <body>
    <div id="game-container">
      <canvas id="loadingCanvas" oncontextmenu="event.preventDefault()" width="1280" height="720"></canvas>
      <canvas id="canvas" oncontextmenu="event.preventDefault()"></canvas>
    </div>

    <script type='text/javascript'>
      function goFullScreen(){{
        var el = document.getElementById("game-container") || document.getElementById("canvas");
        if(el.requestFullScreen)
            el.requestFullScreen();
        else if(el.webkitRequestFullScreen)
            el.webkitRequestFullScreen();
        else if(el.mozRequestFullScreen)
            el.mozRequestFullScreen();
      }}
      var loadingContext = document.getElementById('loadingCanvas').getContext('2d');
      function drawLoadingText(text) {{
        var canvas = loadingContext.canvas;

        loadingContext.fillStyle = "rgb(0, 0, 0)";
        loadingContext.fillRect(0, 0, canvas.width, canvas.height);

        loadingContext.font = 'bold 32px sans-serif';
        loadingContext.textAlign = 'center';
        loadingContext.fillStyle = "rgb(255, 255, 255)";
        loadingContext.fillText(text, canvas.width / 2, canvas.height / 2);

        loadingContext.font = '22px sans-serif';
        loadingContext.fillStyle = "rgb(255, 255, 255)";
        loadingContext.fillText("tech_plague", canvas.width / 2, canvas.height / 4);
        loadingContext.fillText("Powered by Love2D WebAssembly", canvas.width / 2, (canvas.height / 4) * 3);
      }}

      window.onload = function () {{ window.focus(); }};
      window.onclick = function () {{ window.focus(); }};

      window.addEventListener("keydown", function(e) {{
        if([32, 37, 38, 39, 40].indexOf(e.keyCode) > -1) {{
          e.preventDefault();
        }}
      }}, false);

      var Module = {{
        arguments: ["./game.love"],
        INITIAL_MEMORY: 67108864,
        mainScriptUrlOrBlob: 'love.js?ts=' + BUILD_TS,
        printErr: console.error.bind(console),
        locateFile: function(path, prefix) {{
          var base = (prefix || '') + path;
          return base + (base.indexOf('?') >= 0 ? '&' : '?') + 'ts=' + BUILD_TS;
        }},
        canvas: (function() {{
          var canvas = document.getElementById('canvas');
          canvas.addEventListener("webglcontextlost", function(e) {{
            alert('WebGL context lost. You will need to reload the page.');
            e.preventDefault();
          }}, false);
          return canvas;
        }})(),
        setStatus: function(text) {{
          if (text) {{
            drawLoadingText(text);
          }} else if (Module.remainingDependencies === 0) {{
            document.getElementById('loadingCanvas').style.display = 'none';
            document.getElementById('canvas').style.visibility = 'visible';
          }}
        }},
        totalDependencies: 0,
        remainingDependencies: 0,
        monitorRunDependencies: function(left) {{
          this.remainingDependencies = left;
          this.totalDependencies = Math.max(this.totalDependencies, left);
          Module.setStatus(left ? 'Loading... (' + (this.totalDependencies-left) + '/' + this.totalDependencies + ')' : 'All assets loaded.');
        }}
      }};
      Module.setStatus('Loading assets...');
      window.onerror = function(event) {{
        Module.setStatus('Loading error. See browser console.');
        Module.setStatus = function(text) {{
          if (text) Module.printErr('[post-exception status] ' + text);
        }};
      }};

      var applicationLoad = function(e) {{
        Love(Module);
      }};

      (function() {{
        var s1 = document.createElement('script');
        s1.type = 'text/javascript';
        s1.src = 'game.js?ts=' + BUILD_TS;
        s1.onload = function() {{
          var s2 = document.createElement('script');
          s2.type = 'text/javascript';
          s2.async = true;
          s2.src = 'love.js?ts=' + BUILD_TS;
          s2.onload = function() {{
            applicationLoad(this);
          }};
          document.body.appendChild(s2);
        }};
        document.body.appendChild(s1);
      }})();
    </script>
  </body>
</html>
"""
    index_html_path.write_text(html_content, encoding="utf-8")
    print("  ✓ index.html updated successfully with locateFile ?ts= support")

def serve_directory(directory: Path, port: int = 8080):
    """Запускает многопоточный HTTP сервер с no-cache заголовками и правильными MIME-типами."""
    from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
    
    class NoCacheHTTPRequestHandler(SimpleHTTPRequestHandler):
        extensions_map = {
            **SimpleHTTPRequestHandler.extensions_map,
            '.wasm': 'application/wasm',
            '.data': 'application/octet-stream',
            '.js': 'application/javascript',
            '.css': 'text/css',
            '.html': 'text/html',
        }

        def end_headers(self):
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
            self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
            super().end_headers()

        def copyfile(self, source, outputfile):
            try:
                super().copyfile(source, outputfile)
            except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
                pass
            
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(directory), **kwargs)

    class CustomServer(ThreadingHTTPServer):
        daemon_threads = True
        request_queue_size = 64
        allow_reuse_address = True

    server = CustomServer(('127.0.0.1', port), NoCacheHTTPRequestHandler)
    print(f"\n[HTTP Server] Running multithreaded at http://127.0.0.1:{port}/")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")

def main():
    parser = argparse.ArgumentParser(description="Сборка веб-версии Love2D с защитой от кеширования (?ts=).")
    parser.add_argument("--serve", "--server", action="store_true", dest="serve", help="Запустить локальный тестовый HTTP-сервер после сборки")
    parser.add_argument("--port", type=int, default=8080, help="Порт для локального сервера (по умолчанию 8080)")
    args = parser.parse_args()

    root_dir = Path(__file__).resolve().parent.parent
    web_dir = root_dir / "web-build"
    web_dir.mkdir(exist_ok=True)
    
    build_ts = int(time.time() * 1000)
    package_uuid = str(uuid.uuid4())
    
    # 1. Сборка game.data и tech_plague.love
    game_data_path = web_dir / "game.data"
    tech_plague_love_path = root_dir / "tech_plague.love"
    
    file_size = build_love_archive(root_dir, game_data_path)
    # Копируем также в корень как tech_plague.love
    import shutil
    shutil.copy2(game_data_path, tech_plague_love_path)
    
    # 2. Обновление game.js
    update_game_js(web_dir, file_size, package_uuid)
    
    # 3. Обновление index.html
    update_index_html(web_dir, build_ts)
    
    print(f"\n✨ [УСПЕХ] Веб-билд успешно собран в папке: {web_dir}")
    print(f"   • Размер пакета: {file_size:,} байт")
    print(f"   • Build Timestamp: {build_ts}")
    print(f"   • Package UUID: {package_uuid}")
    print(f"   • Все ассеты (game.js, love.js, love.wasm, game.data, love.css) загружаются с '?ts={build_ts}'")

    if args.serve:
        serve_directory(web_dir, port=args.port)

if __name__ == "__main__":
    main()

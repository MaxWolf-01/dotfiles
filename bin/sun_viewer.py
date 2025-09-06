#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "requests",
#   "pillow",
#   "pygame",
#   "numpy",
# ]
# requires-python = ">=3.10"
# ///

"""Live solar imagery viewer using Helioviewer API."""

from __future__ import annotations

import argparse
import bisect
import json
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path
from typing import Final, TypeAlias

import numpy as np
import pygame
import requests
from PIL import Image

# Type aliases
ImageBuffer: TypeAlias = list[tuple[pygame.Surface, str, str]]  # (surface, timestamp, image_id)
SourceId: TypeAlias = int

# Constants
CACHE_DIR: Final = Path("/tmp/sun_viewer_cache")
API_BASE: Final = "https://api.helioviewer.org/v2/"
DEFAULT_FPS: Final = 2
DEFAULT_BUFFER_SIZE: Final = 60
POLL_INTERVAL: Final = 60
WINDOW_SIZE: Final = (1024, 1024)

# Solar observation sources
SOURCES: Final[dict[str, SourceId]] = {
    # SDO/AIA wavelengths
    '304': 13, '171': 10, '193': 11, '211': 12, '335': 14,
    '094': 8, '131': 9, '1600': 15, '1700': 16, '4500': 17,
    # SDO/HMI
    'hmi': 18, 'magnetogram': 19,
    # SOHO/LASCO
    'c2': 4, 'c3': 5,
    # PROBA-2/SWAP
    'swap': 32,
}

SOURCE_NAMES: Final = {v: k for k, v in SOURCES.items()}

WAVELENGTH_INFO: Final = {
    '304': '304Å - Chromosphere (50,000K)',
    '171': '171Å - Quiet corona (600,000K)',
    '193': '193Å - Corona & flares (1.2M K)',
    '211': '211Å - Active regions (2M K)',
    '335': '335Å - Active regions (2.5M K)',
    '094': '094Å - Flaring regions (6M K)',
    '131': '131Å - Flares (10M K)',
    '1600': '1600Å - Transition region',
    '1700': '1700Å - Photosphere',
    '4500': '4500Å - Visible light',
    'hmi': 'HMI - Magnetic intensity',
    'magnetogram': 'Magnetogram',
    'c2': 'LASCO C2 - Coronagraph',
    'c3': 'LASCO C3 - Coronagraph',
    'swap': 'SWAP 174Å'
}


@dataclass
class ImageMetadata:
    id: str
    timestamp: str
    source_id: SourceId


class CacheManager:
    def __init__(self, cache_dir: Path = CACHE_DIR):
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(exist_ok=True)
        self.metadata_lock = threading.Lock()
        self.metadata = self._load_metadata()
    
    def _load_metadata(self) -> dict:
        metadata_file = self.cache_dir / "metadata.json"
        if metadata_file.exists():
            try:
                return json.loads(metadata_file.read_text())
            except:
                return {}
        return {}
    
    def _save_metadata(self):
        with self.metadata_lock:
            metadata_file = self.cache_dir / "metadata.json"
            metadata_file.write_text(json.dumps(self.metadata))
    
    def get_path(self, source_id: SourceId, image_id: str) -> Path:
        return self.cache_dir / f"{source_id}_{image_id}.jpg"
    
    def save(self, source_id: SourceId, image_id: str, image: Image.Image, timestamp: str):
        try:
            path = self.get_path(source_id, image_id)
            image.save(path, 'JPEG', quality=90)
            
            with self.metadata_lock:
                key = str(source_id)
                if key not in self.metadata:
                    self.metadata[key] = {}
                self.metadata[key][image_id] = {
                    'timestamp': timestamp,
                    'cached_at': time.time()
                }
            self._save_metadata()
        except Exception:
            pass
    
    def load(self, source_id: SourceId, image_id: str) -> Image.Image | None:
        path = self.get_path(source_id, image_id)
        if path.exists():
            try:
                return Image.open(path)
            except:
                pass
        return None
    
    def is_cached(self, source_id: SourceId, image_id: str) -> bool:
        with self.metadata_lock:
            return str(source_id) in self.metadata and image_id in self.metadata[str(source_id)]


class HelioviewerClient:
    def __init__(self, source_id: SourceId):
        self.source_id = source_id
        self.session = requests.Session()
    
    def get_closest_image(self, target_time: datetime) -> dict | None:
        params = {
            'date': target_time.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'sourceId': self.source_id
        }
        try:
            response = self.session.get(f"{API_BASE}getClosestImage/", params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except:
            return None
    
    def download_image(self, image_id: str, width: int = 1024) -> Image.Image | None:
        params = {'id': image_id, 'width': width, 'height': width, 'type': 'jpg'}
        try:
            response = self.session.get(f"{API_BASE}downloadImage/", params=params, timeout=15)
            response.raise_for_status()
            return Image.open(BytesIO(response.content))
        except:
            return None


class SunViewer:
    def __init__(self, source_id: SourceId = 13, initial_mode: str = 'video',
                 poll_interval: int = POLL_INTERVAL):
        pygame.init()
        
        self.source_id = source_id
        self.mode = initial_mode
        self.poll_interval = poll_interval
        self.video_fps = DEFAULT_FPS
        self.prefetch_frames = DEFAULT_BUFFER_SIZE
        
        self.fullscreen = False
        self.show_info = True
        self.show_help = False
        self.window_size = WINDOW_SIZE
        self._setup_display()
        
        self.font_large = pygame.font.Font(None, 24)
        self.font_small = pygame.font.Font(None, 18)
        self.clock = pygame.time.Clock()
        
        self.client = HelioviewerClient(source_id)
        self.cache = CacheManager()
        
        self.buffers: dict[SourceId, ImageBuffer] = {}
        self.image_ids: dict[SourceId, set[str]] = {}
        self.playback_indices: dict[SourceId, int] = {}
        self.current_surface: pygame.Surface | None = None
        self.last_image_time = "Loading..."
        
        self.running = True
        self.fetch_lock = threading.Lock()
        self.prefetch_stop = threading.Event()
        self.prefetch_thread = None
        
        self.fps = 0.0
        self.frame_count = 0
        self.fps_update_time = time.time()
        
        self.mode_message = ""
        self.mode_message_alpha = 0
        
        self._init_buffer(source_id)
    
    def _init_buffer(self, source_id: SourceId):
        if source_id not in self.buffers:
            self.buffers[source_id] = []
            self.image_ids[source_id] = set()
            self.playback_indices[source_id] = 0
    
    def _setup_display(self):
        flags = pygame.FULLSCREEN if self.fullscreen else pygame.RESIZABLE
        self.screen = pygame.display.set_mode(
            (0, 0) if self.fullscreen else self.window_size, flags
        )
        if self.fullscreen:
            self.window_size = (self.screen.get_width(), self.screen.get_height())
        pygame.display.set_caption("Live Sun Viewer")
    
    def _pil_to_surface(self, image: Image.Image) -> pygame.Surface:
        if image.mode != 'RGB':
            image = image.convert('RGB')
        array = np.array(image).transpose(1, 0, 2)
        return pygame.surfarray.make_surface(array)
    
    def _scale_to_fit(self, surface: pygame.Surface) -> pygame.Surface:
        sw, sh = surface.get_size()
        ww, wh = self.window_size
        scale = min(ww / sw, wh / sh)
        new_size = (int(sw * scale), int(sh * scale))
        return pygame.transform.smoothscale(surface, new_size)
    
    def _show_message(self, text: str, duration: int = 2000):
        self.mode_message = text
        self.mode_message_alpha = 255
        pygame.time.set_timer(pygame.USEREVENT + 1, duration)
    
    def _toggle_fullscreen(self):
        self.fullscreen = not self.fullscreen
        self._setup_display()
    
    def _cycle_source(self, direction: int):
        sources = list(SOURCES.values())
        idx = sources.index(self.source_id)
        self.source_id = sources[(idx + direction) % len(sources)]
        self.client.source_id = self.source_id
        
        self._init_buffer(self.source_id)
        self._start_prefetch(self.source_id)
        
        self._show_message(f"Source: {SOURCE_NAMES.get(self.source_id, 'Unknown')}")
    
    def _start_prefetch(self, source_id: SourceId):
        if self.prefetch_thread and self.prefetch_thread.is_alive():
            self.prefetch_stop.set()
            self.prefetch_thread.join(timeout=0.5)
            self.prefetch_stop.clear()
        
        self.prefetch_thread = threading.Thread(
            target=self._prefetch_historical, 
            args=(source_id,), 
            daemon=True
        )
        self.prefetch_thread.start()
    
    def _toggle_mode(self):
        self.mode = 'live' if self.mode == 'video' else 'video'
        self._show_message(f"Mode: {self.mode.upper()}")
        
        if self.mode == 'live':
            threading.Thread(target=self._fetch_latest, daemon=True).start()
    
    def _fetch_latest(self):
        now = datetime.now(timezone.utc)
        data = self.client.get_closest_image(now - timedelta(seconds=30))
        
        if data and 'id' in data:
            if (image := self.client.download_image(data['id'])):
                surface = self._pil_to_surface(image)
                self.current_surface = surface
                self.last_image_time = data.get('date', 'Unknown')
                self.cache.save(self.source_id, data['id'], image, self.last_image_time)
    
    def _prefetch_historical(self, source_id: SourceId):
        with self.fetch_lock:
            current_count = len(self.buffers.get(source_id, []))
            if current_count >= self.prefetch_frames:
                print(f"Already have {current_count} frames, skipping prefetch")
                return
        
        frames_needed = self.prefetch_frames - current_count
        if frames_needed <= 0:
            return
            
        print(f"Pre-fetching {frames_needed} more frames for source {source_id} (have {current_count}, want {self.prefetch_frames})...")
        
        client = HelioviewerClient(source_id)
        now = datetime.now(timezone.utc)
        cached_count = downloaded_count = skipped_count = 0
        
        # Round to nearest 12-minute boundary for consistent timestamps
        base_minute = (now.minute // 12) * 12
        base_time = now.replace(minute=base_minute, second=0, microsecond=0)
        
        for i in range(self.prefetch_frames):
            if self.prefetch_stop.is_set():
                return
            
            with self.fetch_lock:
                if len(self.buffers.get(source_id, [])) >= self.prefetch_frames:
                    break
            
            target_time = base_time - timedelta(minutes=i * 12)
            
            try:
                if not (data := client.get_closest_image(target_time)):
                    continue
                
                image_id = data['id']
                
                # Check if already in our buffer
                if image_id in self.image_ids.get(source_id, set()):
                    skipped_count += 1
                    continue
                
                timestamp = data.get('date', 'Unknown')
                
                if self.cache.is_cached(source_id, image_id):
                    if image := self.cache.load(source_id, image_id):
                        cached_count += 1
                else:
                    if not (image := client.download_image(image_id)):
                        continue
                    self.cache.save(source_id, image_id, image, timestamp)
                    downloaded_count += 1
                
                try:
                    surface = self._pil_to_surface(image)
                    with self.fetch_lock:
                        self._init_buffer(source_id)
                        bisect.insort(self.buffers[source_id], (surface, timestamp, image_id), key=lambda x: x[1])
                        self.image_ids[source_id].add(image_id)
                except:
                    continue
                    
            except:
                continue
        
        total_frames = len(self.buffers.get(source_id, []))
        print(f"Pre-fetch complete: {total_frames} frames (skipped: {skipped_count}, cached: {cached_count}, downloaded: {downloaded_count})")
    
    def _fetch_worker(self):
        while self.running:
            try:
                now = datetime.now(timezone.utc)
                target_time = now - timedelta(minutes=2)  # Always fetch recent images (2 min accounts for API delay)
                
                if not (data := self.client.get_closest_image(target_time)):
                    continue
                
                image_id = data['id']
                if image_id not in self.image_ids.get(self.source_id, set()):
                    timestamp = data.get('date', 'Unknown')
                    
                    if self.cache.is_cached(self.source_id, image_id):
                        image = self.cache.load(self.source_id, image_id)
                    else:
                        image = self.client.download_image(image_id)
                        if image:
                            self.cache.save(self.source_id, image_id, image, timestamp)
                    
                    if image:
                        try:
                            surface = self._pil_to_surface(image)
                            with self.fetch_lock:
                                self._init_buffer(self.source_id)
                                bisect.insort(self.buffers[self.source_id], (surface, timestamp, image_id), key=lambda x: x[1])
                                self.image_ids[self.source_id].add(image_id)
                                
                                if self.mode == 'live':
                                    self.current_surface = surface
                                    self.last_image_time = timestamp
                        except:
                            pass
            except:
                pass
            
            time.sleep(self.poll_interval)
    
    def _handle_keydown(self, event: pygame.event.Event):
        key = event.key
        mods = event.mod
        
        if key in (pygame.K_ESCAPE, pygame.K_q):
            self.running = False
        elif key == pygame.K_c and (mods & pygame.KMOD_CTRL):
            self.running = False
        elif key in (pygame.K_f, pygame.K_F11):
            self._toggle_fullscreen()
        elif key in (pygame.K_m, pygame.K_SPACE):
            self._toggle_mode()
        elif key == pygame.K_LEFT:
            self._cycle_source(-1)
        elif key == pygame.K_RIGHT:
            self._cycle_source(1)
        elif key == pygame.K_i:
            self.show_info = not self.show_info
            self._show_message(f"Info: {'ON' if self.show_info else 'OFF'}")
        elif key == pygame.K_h:
            self.show_help = not self.show_help
        elif key == pygame.K_UP:
            self.video_fps = min(30, self.video_fps + 1)
            self._show_message(f"Video FPS: {self.video_fps}")
        elif key == pygame.K_DOWN:
            self.video_fps = max(0.5, self.video_fps - 0.5)
            self._show_message(f"Video FPS: {self.video_fps}")
        elif key == pygame.K_b:
            if mods & pygame.KMOD_SHIFT:
                self.prefetch_frames = min(500, self.prefetch_frames + 10)
            else:
                self.prefetch_frames = max(10, self.prefetch_frames - 10)
            self._show_message(f"Buffer: {self.prefetch_frames} frames (~{self.prefetch_frames * 0.2:.1f} hours)")
            self._start_prefetch(self.source_id)
    
    def _draw_info(self):
        if not self.show_info:
            return
        
        source_name = SOURCE_NAMES.get(self.source_id, 'Unknown')
        wavelength_desc = WAVELENGTH_INFO.get(source_name, source_name)
        
        buffer = self.buffers.get(self.source_id, [])
        buffer_info = f"Buffer: {len(buffer)} frames" if self.mode == 'video' else "Live"
        fps_info = f" | Video FPS: {self.video_fps}" if self.mode == 'video' else ""
        
        delay_info = ""
        if self.last_image_time and self.last_image_time != "Loading...":
            try:
                img_dt = datetime.fromisoformat(self.last_image_time.replace('Z', '+00:00'))
                delay_minutes = (datetime.now(timezone.utc) - img_dt).total_seconds() / 60
                delay_info = f" | Delay: {delay_minutes:.1f} min"
            except:
                pass
        
        lines = [
            wavelength_desc,
            f"Mode: {self.mode.upper()} | {buffer_info}{fps_info}",
            f"Image: {self.last_image_time}{delay_info}",
        ]
        
        y = 10
        for line in lines:
            text = self.font_small.render(line, True, (200, 200, 200))
            rect = text.get_rect()
            
            bg = pygame.Surface((rect.width + 10, rect.height + 4))
            bg.set_alpha(180)
            bg.fill((0, 0, 0))
            
            self.screen.blit(bg, (10, y))
            self.screen.blit(text, (15, y + 2))
            y += rect.height + 5
        
        if self.mode_message_alpha > 0:
            msg = self.font_large.render(self.mode_message, True, (255, 255, 255))
            msg.set_alpha(self.mode_message_alpha)
            msg_rect = msg.get_rect(center=(self.window_size[0] // 2, self.window_size[1] // 2))
            
            bg = pygame.Surface((msg_rect.width + 20, msg_rect.height + 10))
            bg.set_alpha(int(self.mode_message_alpha * 0.7))
            bg.fill((0, 0, 0))
            bg_rect = bg.get_rect(center=(self.window_size[0] // 2, self.window_size[1] // 2))
            
            self.screen.blit(bg, bg_rect)
            self.screen.blit(msg, msg_rect)
            
            self.mode_message_alpha = max(0, self.mode_message_alpha - 5)
    
    def _draw_help(self):
        overlay = pygame.Surface(self.window_size)
        overlay.set_alpha(240)
        overlay.fill((0, 0, 0))
        self.screen.blit(overlay, (0, 0))
        
        lines = [
            "KEYBOARD SHORTCUTS",
            "",
            "F / F11        - Toggle fullscreen",
            "M / Space      - Switch mode (Live/Video)",
            "Left/Right     - Cycle through wavelengths",
            "Up/Down        - Adjust video FPS (0.5-30)",
            "b / B          - Decrease/increase buffer size",
            "I              - Toggle info display",
            "H              - Show/hide this help",
            "ESC / Q / Ctrl+C - Quit",
        ]
        
        y = self.window_size[1] // 2 - len(lines) * 15
        for line in lines:
            font = self.font_large if line == "KEYBOARD SHORTCUTS" else self.font_small
            color = (255, 200, 0) if line == "KEYBOARD SHORTCUTS" else (255, 255, 255)
            text = font.render(line, True, color)
            rect = text.get_rect(center=(self.window_size[0] // 2, y))
            self.screen.blit(text, rect)
            y += 30
    
    def run(self):
        self._start_prefetch(self.source_id)
        threading.Thread(target=self._fetch_worker, daemon=True).start()
        
        self._show_message("Loading solar imagery...", 3000)
        
        playback_counter = 0
        
        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                elif event.type == pygame.KEYDOWN:
                    self._handle_keydown(event)
                elif event.type == pygame.VIDEORESIZE and not self.fullscreen:
                    self.window_size = (event.w, event.h)
                    self.screen = pygame.display.set_mode(self.window_size, pygame.RESIZABLE)
                elif event.type == pygame.USEREVENT + 1:
                    pygame.time.set_timer(pygame.USEREVENT + 1, 0)
            
            self.screen.fill((0, 0, 0))
            
            buffer = self.buffers.get(self.source_id, [])
            
            if self.mode == 'video' and buffer:
                playback_counter += 1
                playback_interval = max(1, int(60 / self.video_fps))
                
                if playback_counter >= playback_interval:
                    playback_counter = 0
                    with self.fetch_lock:
                        if buffer:
                            idx = self.playback_indices.get(self.source_id, 0)
                            if idx >= len(buffer):
                                idx = 0
                            
                            self.current_surface, self.last_image_time, _ = buffer[idx]
                            self.playback_indices[self.source_id] = (idx + 1) % len(buffer)
            
            if self.current_surface:
                scaled = self._scale_to_fit(self.current_surface)
                x = (self.window_size[0] - scaled.get_width()) // 2
                y = (self.window_size[1] - scaled.get_height()) // 2
                self.screen.blit(scaled, (x, y))
            
            if self.show_help:
                self._draw_help()
            else:
                self._draw_info()
            
            pygame.display.flip()
            
            self.frame_count += 1
            if (current_time := time.time()) - self.fps_update_time >= 1.0:
                self.fps = self.frame_count / (current_time - self.fps_update_time)
                self.frame_count = 0
                self.fps_update_time = current_time
            
            self.clock.tick(60)
        
        pygame.quit()


def main():
    parser = argparse.ArgumentParser(
        description='Live Sun Viewer - Display near-real-time solar imagery',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Keyboard shortcuts:
  F / F11      - Toggle fullscreen
  M / Space    - Switch between Live and Video modes
  ← / →        - Cycle through wavelengths
  ↑ / ↓        - Adjust video FPS (0.5-30)
  b / B        - Decrease/increase buffer size
  I            - Toggle info display
  H            - Show help
  ESC / Q / Ctrl+C - Quit

Available sources (--source):
  304, 171, 193, 211  - SDO/AIA wavelengths
  hmi, magnetogram    - SDO/HMI instruments
  c2, c3              - SOHO/LASCO coronagraphs
        """
    )
    
    parser.add_argument('--source', default='304', choices=list(SOURCES.keys()),
                       help='Initial image source/wavelength (default: 304)')
    parser.add_argument('--mode', default='video', choices=['live', 'video'],
                       help='Initial display mode (default: video)')
    parser.add_argument('--poll-interval', type=int, default=60,
                       help='Seconds between API polls (default: 60)')
    parser.add_argument('--fullscreen', action='store_true',
                       help='Start in fullscreen mode')
    
    args = parser.parse_args()
    
    print(f"Starting Sun Viewer...")
    print(f"Mode: {args.mode}, Source: {args.source}")
    print(f"Press H for help, F for fullscreen")
    
    viewer = SunViewer(
        source_id=SOURCES[args.source],
        initial_mode=args.mode,
        poll_interval=args.poll_interval
    )
    
    if args.fullscreen:
        viewer._toggle_fullscreen()
    
    try:
        viewer.run()
    except KeyboardInterrupt:
        print("\nShutting down...")
        sys.exit(0)


if __name__ == "__main__":
    main()
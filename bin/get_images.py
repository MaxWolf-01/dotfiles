import requests
from bs4 import BeautifulSoup
import os
from urllib.parse import urljoin, urlparse
import re
import argparse

def sanitize_url_to_filename(url: str) -> str:
    """
    Convert a URL into a safe filename:
    - Lowercase
    - Replace non-alphanumeric characters with hyphens
    - Collapse multiple hyphens
    - Strip leading or trailing hyphens
    """
    parsed = urlparse(url)
    base = (parsed.netloc + parsed.path).lower()
    safe = re.sub(r'[^a-z0-9]', '-', base)
    safe = re.sub(r'-{2,}', '-', safe)
    safe = safe.strip('-')
    return safe or "downloaded-images"

def download_images_from_url(url: str, dest_root: str = None):
    safe_name = sanitize_url_to_filename(url)
    root = dest_root or os.getcwd()
    folder = os.path.join(root, safe_name)
    os.makedirs(folder, exist_ok=True)

    print(f"Downloading images from: {url}")
    print(f"Saving into folder: {folder}\n")

    try:
        resp = requests.get(url)
        resp.raise_for_status()
    except Exception as e:
        print(f"Error fetching page: {e}")
        return

    soup = BeautifulSoup(resp.text, "html.parser")
    imgs = soup.find_all("img")

    if not imgs:
        print("No images found on the page.")
        return

    for img in imgs:
        src = img.get("src") or img.get("data-src")
        if not src:
            continue
        img_url = urljoin(url, src)
        img_name = os.path.basename(urlparse(img_url).path)
        if not img_name:  # fallback if empty
            img_name = re.sub(r'[^a-z0-9\-._]', '', sanitize_url_to_filename(img_url))
        dest = os.path.join(folder, img_name)

        try:
            with requests.get(img_url, stream=True) as r:
                r.raise_for_status()
                with open(dest, "wb") as f:
                    for chunk in r.iter_content(chunk_size=1024):
                        f.write(chunk)
            print(f"Saved: {dest}")
        except Exception as e:
            print(f"Failed to download {img_url}: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download all images from a webpage.")
    parser.add_argument("url", help="The URL of the webpage to scrape images from")
    parser.add_argument(
        "--dest",
        help="Root destination folder (default: current working directory)",
        default=None,
    )
    args = parser.parse_args()

    download_images_from_url(args.url, args.dest)


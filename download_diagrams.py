import os
import re
import time
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# Create images directory if it doesn't exist
if not os.path.exists('images'):
    os.makedirs('images')

# List of Microsoft Learn pages to scrape
pages = [
    'https://learn.microsoft.com/en-us/azure/architecture/guide/',
    'https://learn.microsoft.com/en-us/azure/architecture/guide/architecture-styles/',
    'https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/',
    'https://learn.microsoft.com/en-us/azure/architecture/patterns/',
    'https://learn.microsoft.com/en-us/azure/architecture/framework/',
    'https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/',
    'https://learn.microsoft.com/en-us/azure/architecture/example-scenario/',
    'https://learn.microsoft.com/en-us/azure/architecture/browse/',
    'https://learn.microsoft.com/en-us/azure/architecture/guide/security/security-start-here',
    'https://learn.microsoft.com/en-us/azure/architecture/framework/security/security-principles',
    'https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/backup-and-recovery',
    'https://learn.microsoft.com/en-us/azure/architecture/framework/scalability/performance-efficiency',
    'https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/compute-decision-tree'
]

def clean_filename(url):
    """Extract a clean filename from the URL."""
    # Remove trailing slash and get the last part of the URL
    name = url.rstrip('/').split('/')[-1]
    # Replace hyphens with underscores and remove any non-alphanumeric characters
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name.replace('-', '_'))
    return name

def download_image(url, filename):
    """Download an image from the given URL and save it with the given filename."""
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        # Determine file extension from content type or URL
        content_type = response.headers.get('content-type', '')
        if 'svg' in content_type or url.endswith('.svg'):
            ext = '.svg'
        elif 'png' in content_type or url.endswith('.png'):
            ext = '.png'
        elif 'jpg' in content_type or 'jpeg' in content_type or url.endswith(('.jpg', '.jpeg')):
            ext = '.jpg'
        else:
            ext = '.png'  # Default to PNG if we can't determine the type
        
        # Save the image
        with open(os.path.join('images', filename + ext), 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        print(f"Downloaded: {filename}{ext}")
        return True
    except Exception as e:
        print(f"Error downloading {url}: {str(e)}")
        return False

def process_page(url):
    """Process a single page and download its architecture diagrams."""
    try:
        # Get the page content
        response = requests.get(url)
        response.raise_for_status()
        
        # Parse the HTML
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Get the page name for the filename
        page_name = clean_filename(url)
        
        # Find all images
        images = soup.find_all('img')
        
        # Counter for multiple images on the same page
        image_count = 0
        
        # Process each image
        for img in images:
            src = img.get('src', '')
            if not src:
                continue
                
            # Convert relative URLs to absolute
            if not src.startswith(('http://', 'https://')):
                src = urljoin(url, src)
            
            # Only download architecture-related images
            if any(keyword in src.lower() for keyword in ['architecture', 'diagram', 'reference']):
                filename = f"{page_name}_{image_count}" if image_count > 0 else page_name
                if download_image(src, filename):
                    image_count += 1
                    # Be nice to the server
                    time.sleep(1)
        
        return image_count
    except Exception as e:
        print(f"Error processing {url}: {str(e)}")
        return 0

def main():
    """Main function to process all pages."""
    total_images = 0
    for url in pages:
        print(f"\nProcessing: {url}")
        images_downloaded = process_page(url)
        total_images += images_downloaded
        print(f"Downloaded {images_downloaded} images from this page")
    
    print(f"\nTotal images downloaded: {total_images}")

if __name__ == "__main__":
    main() 
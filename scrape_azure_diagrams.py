import os
import requests
from urllib.parse import urlparse

# Direct URLs to key Azure architecture diagrams
ARCHITECTURE_IMAGES = [
    # Core Architectures (keeping successful ones)
    ('https://learn.microsoft.com/en-us/azure/architecture/guide/architecture-styles/images/microservices-logical.png', 'microservices-architecture.png'),
    ('https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/images/aks-baseline-architecture.svg', 'aks-baseline-architecture.png'),
    ('https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/images/hub-spoke.png', 'hub-spoke-architecture.png'),
    ('https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/app-service-web-app/images/scalable-web-app.png', 'scalable-web-app-architecture.png'),
    
    # Networking and Connectivity
    ('https://learn.microsoft.com/en-us/azure/virtual-network/media/service-endpoints-overview.png', 'service-endpoints.png'),
    ('https://learn.microsoft.com/en-us/azure/private-link/media/private-endpoint-basics.png', 'private-endpoint-basics.png'),
    ('https://learn.microsoft.com/en-us/azure/private-link/media/private-link-service-overview.png', 'private-link-service.png'),
    ('https://learn.microsoft.com/en-us/azure/dns/media/private-dns-portal.png', 'private-dns-portal.png'),
    ('https://learn.microsoft.com/en-us/azure/virtual-network/media/routing-overview.png', 'vnet-routing-overview.png'),
    
    # DNS and Hybrid Networking
    ('https://learn.microsoft.com/en-us/azure/dns/media/dns-overview.png', 'azure-dns-overview.png'),
    ('https://learn.microsoft.com/en-us/azure/dns/media/private-resolver-overview.png', 'private-resolver-overview.png'),
    ('https://learn.microsoft.com/en-us/azure/dns/media/custom-domain-name.png', 'custom-domain-dns.png'),
    
    # Identity and Security
    ('https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/media/overview/conditional-access-overview.png', 'conditional-access-overview.png'),
    ('https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/media/what-if-tool/what-if-tool.png', 'conditional-access-what-if.png'),
    ('https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/media/location-condition.png', 'conditional-access-location.png'),
    
    # Container and DevSecOps (keeping successful ones)
    ('https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/containers/aks/images/secure-baseline-architecture.svg', 'aks-secure-baseline.png'),
    ('https://learn.microsoft.com/en-us/azure/architecture/solution-ideas/media/devsecops-in-azure.png', 'aks-devsecops.png'),
    ('https://learn.microsoft.com/en-us/azure/container-registry/media/container-registry-service-tiers.png', 'acr-service-tiers.png')
]

def create_images_dir():
    """Create images directory if it doesn't exist"""
    if not os.path.exists('images'):
        os.makedirs('images')

def download_image(url, filename):
    """Download image from URL and save to images directory"""
    try:
        response = requests.get(url)
        response.raise_for_status()
        
        filepath = os.path.join('images', filename)
        with open(filepath, 'wb') as f:
            f.write(response.content)
        print(f"Successfully downloaded: {filename}")
        return True
    except Exception as e:
        print(f"Error downloading {filename}: {str(e)}")
        return False

def download_architecture_diagrams():
    """Download architecture diagrams from direct URLs"""
    create_images_dir()
    
    for url, filename in ARCHITECTURE_IMAGES:
        download_image(url, filename)

if __name__ == '__main__':
    print("Starting to download Azure architecture diagrams...")
    download_architecture_diagrams()
    print("Download completed!") 
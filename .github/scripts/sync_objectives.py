#!/usr/bin/env python3

import os
import re
import requests
from bs4 import BeautifulSoup
from datetime import datetime

def fetch_exam_objectives(url):
    """Fetch and parse exam objectives from Microsoft Learn."""
    response = requests.get(url)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Find the skills measured section
    skills_section = soup.find('h2', string=re.compile(r'Skills measured', re.I))
    if not skills_section:
        raise ValueError("Could not find skills measured section")
    
    return parse_objectives(skills_section)

def parse_objectives(section):
    """Parse the objectives into a structured format."""
    objectives = {
        'last_updated': datetime.now().strftime('%B %d, %Y'),
        'sections': []
    }
    
    current_section = None
    for elem in section.find_all_next(['h3', 'ul']):
        if elem.name == 'h3':
            if current_section:
                objectives['sections'].append(current_section)
            current_section = {
                'title': elem.text.strip(),
                'items': []
            }
        elif elem.name == 'ul' and current_section:
            for item in elem.find_all('li'):
                current_section['items'].append(item.text.strip())
    
    if current_section:
        objectives['sections'].append(current_section)
    
    return objectives

def generate_markdown(objectives):
    """Generate markdown content with emoji."""
    emoji_map = {
        'Identity': '🔐',
        'Data': '💾',
        'Business': '🔄',
        'Infrastructure': '🏗️',
        'Compute': '🖥️',
        'Application': '🏛️',
        'Migration': '🚀',
        'Network': '🌐'
    }
    
    md = [
        f"# 🏆 AZ-305: Azure Solutions Architect Expert\n",
        f"> 📅 {objectives['last_updated']}\n",
        "## 🎯 Exam Sections\n"
    ]
    
    # Add section summaries
    for section in objectives['sections']:
        title = section['title'].split('(')[0].strip()
        weight = re.search(r'\((\d+–\d+%)\)', section['title'])
        weight = weight.group(1) if weight else ''
        emoji = next((v for k, v in emoji_map.items() if k in title), '📌')
        md.append(f"- {title} ({weight})")
    
    md.append("\n## 📚 Technical Requirements\n")
    
    # Add detailed sections
    for i, section in enumerate(objectives['sections'], 1):
        title = section['title'].split('(')[0].strip()
        weight = re.search(r'\((\d+–\d+%)\)', section['title'])
        weight = weight.group(1) if weight else ''
        emoji = next((v for k, v in emoji_map.items() if k in title), '📌')
        
        md.append(f"### {i}. {emoji} {title} ({weight})\n")
        for item in section['items']:
            md.append(f"- {item}")
        md.append("")
    
    return '\n'.join(md)

def update_objectives_file():
    """Update the objectives markdown file."""
    exam_url = os.getenv('EXAM_URL')
    if not exam_url:
        raise ValueError("EXAM_URL environment variable not set")
    
    objectives = fetch_exam_objectives(exam_url)
    markdown = generate_markdown(objectives)
    
    with open('az305-exam-metadata/az305-OD.md', 'w', encoding='utf-8') as f:
        f.write(markdown)

if __name__ == '__main__':
    update_objectives_file() 
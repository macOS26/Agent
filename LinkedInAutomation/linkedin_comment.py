#!/usr/bin/env python3

import requests
import json
import os
import time
from urllib.parse import urlparse, parse_qs

# Configuration
LINKEDIN_API_URL = "https://api.linkedin.com/rest/socialActions/{urn}/comments"
LINKEDIN_SEARCH_URL = "https://api.linkedin.com/rest/posts?q=keyword&keywords=OpenClaw%20Mac%20Mini&count=20"
OAUTH_TOKEN = os.getenv("LINKEDIN_OAUTH_TOKEN")  # Set this in your environment
LINKEDIN_VERSION = "202406"  # Update to the latest version
COMMENT_TEXT = """For those who would prefer the simplicity of a native Mac app there's Agent! for macOS26, an AgenticAI that can automate any app and anything else you desire for your automated workflow. It's less than a week old, Agent! can also write code and has written over 50% of its latest incarnations. macOS26.app plus it's open source github.com/macOS26/agent works best with Ollama glm-5 and other Ollama Pro cloud-based models for just $20 a month. It also supports Claude API and local Ollama LLMs."""

HEADERS = {
    "Authorization": f"Bearer {OAUTH_TOKEN}",
    "LinkedIn-Version": LINKEDIN_VERSION,
    "X-Restli-Protocol-Version": "2.0.0",
    "Content-Type": "application/json"
}


def extract_post_urn(post_url_or_urn):
    """Extract LinkedIn URN from URL or return as-is if already a URN."""
    if post_url_or_urn.startswith("urn:li:"):
        return post_url_or_urn
    
    # Handle LinkedIn post URLs
    parsed = urlparse(post_url_or_urn)
    if "linkedin.com" in parsed.netloc and "/posts/" in parsed.path:
        path_parts = parsed.path.split("/")
        for i, part in enumerate(path_parts):
            if part == "posts" and i + 1 < len(path_parts):
                return f"urn:li:share:{path_parts[i+1]}"
    
    # Handle URNs in query parameters (e.g., from search results)
    query = parse_qs(parsed.query)
    if "shareId" in query:
        return f"urn:li:share:{query['shareId'][0]}"
    
    raise ValueError(f"Could not extract URN from: {post_url_or_urn}")


def search_linkedin_posts(keyword="OpenClaw Mac Mini", count=20):
    """Search LinkedIn for posts containing the keyword."""
    search_url = f"https://api.linkedin.com/rest/posts?q=keyword&keywords={keyword}&count={count}"
    response = requests.get(search_url, headers=HEADERS)
    
    if response.status_code != 200:
        print(f"Search failed: {response.status_code} - {response.text}")
        return []
    
    try:
        posts = response.json().get("elements", [])
        return [post.get("id") for post in posts]
    except Exception as e:
        print(f"Failed to parse search results: {e}")
        return []


def post_comment(urn, comment_text):
    """Post a comment on a LinkedIn post."""
    payload = {
        "actor": "urn:li:person:" + os.getenv("LINKEDIN_PERSON_URN"),  # Set this in your environment
        "object": urn,
        "message": {
            "text": comment_text
        }
    }
    
    response = requests.post(
        LINKEDIN_API_URL.format(urn=urn),
        headers=HEADERS,
        data=json.dumps(payload)
    )
    
    if response.status_code == 201:
        print(f"Successfully posted comment on {urn}")
        return True
    else:
        print(f"Failed to post comment on {urn}: {response.status_code} - {response.text}")
        return False


def main():
    if not OAUTH_TOKEN:
        print("Error: LINKEDIN_OAUTH_TOKEN environment variable not set.")
        return
    
    if not os.getenv("LINKEDIN_PERSON_URN"):
        print("Error: LINKEDIN_PERSON_URN environment variable not set.")
        return
    
    # Search for posts mentioning "OpenClaw Mac Mini"
    post_urns = search_linkedin_posts()
    if not post_urns:
        print("No posts found or search failed.")
        return
    
    print(f"Found {len(post_urns)} posts. Posting comments...")
    
    # Post comments on each post
    for urn in post_urns:
        success = post_comment(urn, COMMENT_TEXT)
        if not success:
            print(f"Skipping further comments due to rate limits or errors.")
            break
        time.sleep(2)  # Avoid hitting rate limits


if __name__ == "__main__":
    main()
import requests
import feedparser
import time
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
from newspaper import Article
from typing import List, Dict
import logging

class NewsCollector:
    def __init__(self):
        self.ai_keywords = [
            'artificial intelligence', 'ai', 'machine learning', 'ml', 'deep learning',
            'neural network', 'chatgpt', 'openai', 'anthropic', 'claude', 'gpt',
            'llm', 'large language model', 'automation', 'robotics', 'computer vision',
            'natural language processing', 'nlp', 'generative ai', 'ai model'
        ]
        
        self.news_sources = {
            'TechCrunch AI': 'https://techcrunch.com/category/artificial-intelligence/feed/',
            'Ars Technica': 'https://feeds.arstechnica.com/arstechnica/index',
            'MIT Technology Review': 'https://www.technologyreview.com/feed/',
            'The Verge': 'https://www.theverge.com/rss/index.xml',
            'Wired': 'https://www.wired.com/feed/rss',
            'AI News': 'https://artificialintelligence-news.com/feed/',
            'VentureBeat AI': 'https://venturebeat.com/ai/feed/',
            'IEEE Spectrum': 'https://spectrum.ieee.org/rss/fulltext',
        }
        
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })

    def is_ai_related(self, title: str, content: str = "") -> bool:
        """Check if the article is AI-related based on keywords."""
        text = f"{title} {content}".lower()
        return any(keyword in text for keyword in self.ai_keywords)

    def fetch_rss_feed(self, url: str, source_name: str) -> List[Dict]:
        """Fetch articles from RSS feed."""
        articles = []
        try:
            feed = feedparser.parse(url)
            for entry in feed.entries[:20]:  # Limit to recent articles
                if hasattr(entry, 'published_parsed'):
                    pub_date = datetime(*entry.published_parsed[:6])
                else:
                    pub_date = datetime.now()
                
                # Only get articles from last 24 hours
                if datetime.now() - pub_date > timedelta(days=1):
                    continue
                
                title = entry.title
                summary = getattr(entry, 'summary', '')
                
                if self.is_ai_related(title, summary):
                    article = {
                        'title': title,
                        'url': entry.link,
                        'summary': summary,
                        'source': source_name,
                        'published': pub_date,
                        'content': ''
                    }
                    articles.append(article)
                    
        except Exception as e:
            logging.error(f"Error fetching RSS feed {url}: {e}")
        
        return articles

    def extract_article_content(self, article: Dict) -> Dict:
        """Extract full content from article URL."""
        try:
            news_article = Article(article['url'])
            news_article.download()
            news_article.parse()
            
            article['content'] = news_article.text[:1000]  # Limit content length
            if not article['summary']:
                article['summary'] = news_article.text[:300] + "..."
                
        except Exception as e:
            logging.error(f"Error extracting content from {article['url']}: {e}")
        
        return article

    def collect_ai_news(self) -> List[Dict]:
        """Collect AI-related news from all sources."""
        all_articles = []
        
        for source_name, feed_url in self.news_sources.items():
            logging.info(f"Fetching news from {source_name}")
            articles = self.fetch_rss_feed(feed_url, source_name)
            
            # Extract full content for top articles
            for article in articles[:5]:  # Limit content extraction
                article = self.extract_article_content(article)
                all_articles.append(article)
            
            time.sleep(1)  # Be respectful to servers
        
        # Remove duplicates based on title similarity
        unique_articles = self.remove_duplicates(all_articles)
        
        # Sort by publication date (newest first)
        unique_articles.sort(key=lambda x: x['published'], reverse=True)
        
        return unique_articles

    def remove_duplicates(self, articles: List[Dict]) -> List[Dict]:
        """Remove duplicate articles based on title similarity."""
        unique_articles = []
        seen_titles = set()
        
        for article in articles:
            title_words = set(article['title'].lower().split())
            is_duplicate = False
            
            for seen_title in seen_titles:
                seen_words = set(seen_title.lower().split())
                # If more than 70% of words overlap, consider it duplicate
                overlap = len(title_words.intersection(seen_words))
                if overlap / len(title_words.union(seen_words)) > 0.7:
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                unique_articles.append(article)
                seen_titles.add(article['title'])
        
        return unique_articles
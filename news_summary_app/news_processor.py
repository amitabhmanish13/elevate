import os
from typing import List, Dict
from datetime import datetime
import logging

try:
    import openai
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False

class NewsProcessor:
    def __init__(self):
        self.openai_available = OPENAI_AVAILABLE and os.getenv('OPENAI_API_KEY')
        if self.openai_available:
            openai.api_key = os.getenv('OPENAI_API_KEY')
        
        # Scoring weights for different factors
        self.scoring_weights = {
            'recency': 0.3,      # How recent the article is
            'source_quality': 0.2,  # Quality of the news source
            'ai_relevance': 0.3,    # How relevant to AI
            'engagement': 0.2,      # Potential for engagement
        }
        
        # Source quality rankings (higher is better)
        self.source_rankings = {
            'MIT Technology Review': 10,
            'TechCrunch AI': 9,
            'Ars Technica': 8,
            'The Verge': 8,
            'Wired': 8,
            'IEEE Spectrum': 9,
            'VentureBeat AI': 7,
            'AI News': 6,
        }
        
        # High-value AI keywords (give extra relevance score)
        self.high_value_keywords = [
            'breakthrough', 'announcement', 'release', 'launch', 'funding',
            'acquisition', 'research', 'development', 'innovation', 'breakthrough',
            'chatgpt', 'openai', 'anthropic', 'google ai', 'microsoft ai',
            'nvidia', 'tesla', 'autonomous', 'robotics'
        ]

    def calculate_recency_score(self, published_date: datetime) -> float:
        """Calculate recency score (0-10) based on how recent the article is."""
        hours_ago = (datetime.now() - published_date).total_seconds() / 3600
        
        if hours_ago <= 2:
            return 10.0
        elif hours_ago <= 6:
            return 8.0
        elif hours_ago <= 12:
            return 6.0
        elif hours_ago <= 24:
            return 4.0
        else:
            return 2.0

    def calculate_source_quality_score(self, source: str) -> float:
        """Calculate source quality score (0-10)."""
        return self.source_rankings.get(source, 5.0)

    def calculate_ai_relevance_score(self, title: str, summary: str, content: str) -> float:
        """Calculate AI relevance score (0-10) based on content analysis."""
        text = f"{title} {summary} {content}".lower()
        
        # Base score for AI keywords
        base_keywords = [
            'artificial intelligence', 'ai', 'machine learning', 'ml', 'deep learning',
            'neural network', 'llm', 'gpt', 'chatbot', 'automation'
        ]
        
        base_score = sum(2 for keyword in base_keywords if keyword in text)
        
        # Bonus for high-value keywords
        bonus_score = sum(1 for keyword in self.high_value_keywords if keyword in text)
        
        # Title relevance bonus
        title_bonus = 2 if any(keyword in title.lower() for keyword in base_keywords) else 0
        
        total_score = min(10.0, base_score + bonus_score + title_bonus)
        return total_score

    def calculate_engagement_score(self, title: str, summary: str) -> float:
        """Calculate potential engagement score (0-10) based on title and summary."""
        engagement_indicators = [
            'new', 'latest', 'breakthrough', 'first', 'major', 'significant',
            'revolutionary', 'game-changing', 'unprecedented', 'announces',
            'launches', 'releases', 'unveils', 'reveals', 'discovers'
        ]
        
        text = f"{title} {summary}".lower()
        score = sum(1 for indicator in engagement_indicators if indicator in text)
        
        # Bonus for question marks or numbers in title
        if '?' in title:
            score += 1
        if any(char.isdigit() for char in title):
            score += 1
        
        return min(10.0, score)

    def score_article(self, article: Dict) -> float:
        """Calculate overall score for an article."""
        recency_score = self.calculate_recency_score(article['published'])
        source_score = self.calculate_source_quality_score(article['source'])
        relevance_score = self.calculate_ai_relevance_score(
            article['title'], article['summary'], article.get('content', '')
        )
        engagement_score = self.calculate_engagement_score(article['title'], article['summary'])
        
        # Calculate weighted score
        total_score = (
            recency_score * self.scoring_weights['recency'] +
            source_score * self.scoring_weights['source_quality'] +
            relevance_score * self.scoring_weights['ai_relevance'] +
            engagement_score * self.scoring_weights['engagement']
        )
        
        article['score'] = total_score
        article['score_breakdown'] = {
            'recency': recency_score,
            'source_quality': source_score,
            'ai_relevance': relevance_score,
            'engagement': engagement_score
        }
        
        return total_score

    def generate_ai_summary(self, article: Dict) -> str:
        """Generate AI-powered summary if OpenAI is available."""
        if not self.openai_available:
            return article['summary'][:200] + "..." if len(article['summary']) > 200 else article['summary']
        
        try:
            prompt = f"""
            Summarize this AI/tech news article in 2-3 concise sentences that highlight the key points:
            
            Title: {article['title']}
            Content: {article['summary']} {article.get('content', '')}
            
            Focus on what's new, important, and actionable. Keep it under 150 words.
            """
            
            response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=150,
                temperature=0.3
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logging.error(f"Error generating AI summary: {e}")
            return article['summary'][:200] + "..." if len(article['summary']) > 200 else article['summary']

    def process_and_rank_news(self, articles: List[Dict], max_items: int = 10) -> List[Dict]:
        """Process articles, score them, and return top articles."""
        if not articles:
            return []
        
        # Score all articles
        for article in articles:
            self.score_article(article)
        
        # Sort by score (descending)
        ranked_articles = sorted(articles, key=lambda x: x['score'], reverse=True)
        
        # Get top articles
        top_articles = ranked_articles[:max_items]
        
        # Generate AI summaries if available
        for article in top_articles:
            article['ai_summary'] = self.generate_ai_summary(article)
        
        return top_articles

    def format_articles_for_email(self, articles: List[Dict]) -> str:
        """Format articles for email content."""
        if not articles:
            return "No AI news found for today."
        
        email_content = f"""
🤖 **Top {len(articles)} AI Tech News - {datetime.now().strftime('%B %d, %Y')}**

"""
        
        for i, article in enumerate(articles, 1):
            email_content += f"""
📰 **{i}. {article['title']}**
🏢 Source: {article['source']}
⭐ Score: {article['score']:.1f}/10
📅 Published: {article['published'].strftime('%H:%M, %B %d')}

{article['ai_summary']}

🔗 Read more: {article['url']}

{'='*50}

"""
        
        email_content += f"""

📊 **Summary Statistics:**
• Total articles processed: {len(articles)}
• Average relevance score: {sum(a['score'] for a in articles) / len(articles):.1f}/10
• Sources covered: {len(set(a['source'] for a in articles))}

🤖 Generated by AI News Summary Bot
"""
        
        return email_content
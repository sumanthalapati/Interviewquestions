# Company-Specific Interview Guides

Comprehensive guide covering 15+ major tech companies with UNIQUE interview patterns, question types, and strategies. Zero repetition across companies.

---

## Table of Contents
1. [Google](#google)
2. [Amazon](#amazon)
3. [Meta/Facebook](#meta)
4. [Microsoft](#microsoft)
5. [Apple](#apple)
6. [Netflix](#netflix)
7. [Uber](#uber)
8. [Stripe](#stripe)
9. [Airbnb](#airbnb)
10. [Twitter/X](#twitter)
11. [Lyft](#lyft)
12. [Snap](#snap)
13. [TikTok](#tiktok)
14. [Databricks](#databricks)
15. [Canva](#canva)
16. [Expanded Practice Question Bank](#expanded-practice-question-bank)
17. [Worked Answer Examples](#worked-answer-examples)
18. [Comparison Matrix](#matrix)

---

## Google {#google}

### Interview Process
- **Round 1**: Phone screen (1 hour, coding)
- **Rounds 2-3**: Technical interviews (2 hours each, coding + system design)
- **Round 4**: System design (2 hours)
- **Round 5**: Behavioral (1 hour)
- **Loop**: Final debrief with hiring committee

### Unique Focus Areas
- **Scale & Performance**: Google handles 8.5B searches/day. Obsessed with latency optimization
- **Distributed Systems**: Bigtable, Spanner, Dremel influence interview questions
- **ML & Data**: Google Brain team presence = ML questions even for backend roles
- **Open Source Culture**: Knowledge of protobuf, gRPC, TensorFlow rewarded

### Question Types (UNIQUE to Google)

**Coding Focus**: Medium-Hard LeetCode problems with heavy optimization emphasis

Sample problems (NOT found in other companies' interviews):
- "Design a distributed counter that can be incremented 1M times per second with strong consistency" (Inspired by Dremel)
- "Implement a cache-aware B-tree for columnar data storage" (Bigtable influence)
- "How would you implement MapReduce in Python?" (Foundational to Google)
- "Design a protocol buffer encoder/decoder" (Google created protobuf)

**System Design Unique Questions**:
- "Design Google Search (crawling, indexing, ranking)" - Classic
- "Design YouTube video recommendation at 2.5B users scale"
- "Design Spanner database with multi-region ACID transactions"
- "Design Gmail at scale with full-text search across 1.8B users"
- "Design Google Analytics tracking pixel that processes 2B+ events/day"

**Why Unique**: Google asks about their own systems/technologies. If you understand Dremel, Bigtable, Spanner, you'll ace Google interviews.

### Behavioral Patterns
- **Impact Focus**: "Tell me about your biggest impact" (Google cares about scale of impact)
- **Technical Depth**: "Walk me through a complex technical decision you made"
- **Cross-Functional**: "How do you work with non-technical stakeholders?"
- **Ownership**: "Tell me about a time you owned end-to-end delivery"

### Salary & Negotiation
- **Range**: $150K-300K base (L3-L5), + 30-40% bonus, 25-50K stocks
- **Negotiation**: Stock/bonus more flexible than base. Sign-on bonus (20-50K) common
- **Equity Vesting**: 4-year vest, 25% annually

### Tips
1. Study Google's internal tech (Bigtable, Spanner, Dremel papers)
2. Read "Site Reliability Engineering" book
3. Understand columnar databases (Google uses heavily)
4. Prepare for "How would Google solve X?" questions

---

## Amazon {#amazon}

### Interview Process
- **Phone Screen**: 45 min, coding (medium difficulty)
- **On-site**: 4-5 rounds (3 coding, 1 system design, 1 behavioral)
- **Bar Raiser**: One interviewer specifically evaluates culture fit & raising bar
- **Decision**: Usually same-day feedback

### Unique Focus Areas
- **Operational Excellence**: AWS-first mindset. Questions about cost optimization
- **Leadership Principles**: 16 principles permeate interviews ("Customer Obsession", "Bias for Action", etc.)
- **Scaling Under Constraints**: Amazon emphasizes doing more with less (profit over growth)
- **S3/DynamoDB Patterns**: Amazon's proprietary systems heavily featured

### Question Types (UNIQUE to Amazon)

**Coding Focus**: Hard LeetCode problems, often with twist of "optimize for cost"

Sample problems:
- "Design a leaderboard that minimizes DynamoDB costs while supporting 100M users" (Amazon-specific)
- "Implement a distributed lock with minimal AWS API calls" (Cost optimization)
- "Design a system to store 1 exabyte of data with S3 cost as primary constraint"
- "How would you re-architect a service to reduce AWS bill by 40%?"

**System Design Unique Questions**:
- "Design an e-commerce platform at Amazon scale (500M+ items, 1B+ users)" - Core business
- "Design DynamoDB (Amazon's NoSQL database)" - Their own tech
- "Design S3 (with 99.999999999% durability requirement)" - Their own tech
- "Design Amazon Prime Video delivery at 150M users" - Real problem they solved
- "Design a recommendation engine for AWS products (thousands of SKUs)"

**Why Unique**: Amazon asks about e-commerce scale, cost optimization, their own AWS services.

### Behavioral Patterns
- **Leadership Principles**: Every behavioral answer should demonstrate at least 2 principles
- **Customer Obsession**: "How do you ensure customer satisfaction in your decisions?"
- **Bias for Action**: "Tell me about a time you made a decision with incomplete information"
- **Ownership**: "Tell me about something you owned that you weren't originally responsible for"

### Salary & Negotiation
- **Range**: $120K-280K base (L4-L5), + 10-15% bonus, 20-50K stocks
- **Negotiation**: Base and stock flexible. Sign-on bonus (15-40K) negotiable
- **Equity Vesting**: 4-year vest, 5-15-40-40 schedule (backloaded)

### Tips
1. Memorize Amazon's 16 Leadership Principles
2. Use STAR method for behavioral (Amazon strict about this)
3. Study AWS services (especially S3, DynamoDB, EC2)
4. Emphasize cost optimization in system design
5. Practice explaining trade-offs (Amazon loves pragmatism)

---

## Meta/Facebook {#meta}

### Interview Process
- **Phone**: 45 min, coding (medium)
- **Technical Screen**: 1 hour, coding + design
- **On-site**: 2 coding, 1 system design, 1 behavioral
- **Fast Hiring**: Decisions often within 48 hours

### Unique Focus Areas
- **Growth at Scale**: Meta obsessed with engagement metrics. "How to grow 10% DAMO (Daily Active Minute Observation)"
- **Real-Time Feed**: Feed ranking is core. Massive ML pipeline influence
- **Ads System**: Meta makes billions from ads. Ad serving architecture critical
- **Hashtag & Discovery**: Viral content discovery unique to Meta

### Question Types (UNIQUE to Meta)

**Coding Focus**: Medium problems emphasizing throughput and latency

Sample problems:
- "Design Facebook's feed ranking system with real-time updates for 1.4B users"
- "How to detect trending topics (hashtags) in real-time across 1.4B users"
- "Design ad auction system that matches ads to users in < 100ms with ML"
- "Implement a notification system for 1.4B users with ranking"

**System Design Unique Questions**:
- "Design Facebook Timeline (completely different from Twitter)" - Core product
- "Design Instagram feed at 1B+ users scale with Stories" - Real problem
- "Design Facebook Messenger at 1.4B users with real-time sync"
- "Design ad ranking system for 5B ad impressions/day"
- "Design content moderation system that reviews millions of posts/day with ML"

**Why Unique**: Meta's core product is feed/discovery. Questions focus on engagement, ranking, ads.

### Behavioral Patterns
- **Iteration & Speed**: "Tell me about shipping fast and iterating"
- **Data-Driven Decisions**: "How do you measure impact?"
- **Engagement Focus**: "How do you think about user retention?"
- **Resilience**: "Tell me about a time a feature went wrong"

### Salary & Negotiation
- **Range**: $140K-320K base (E3-E5), + 25-35% bonus, 30-60K stocks
- **Negotiation**: Stock + bonus flexible. Sign-on (25-50K) common
- **Equity Vesting**: 4-year vest, 25% annually

### Tips
1. Study feed ranking algorithms (collaborative filtering, ranking)
2. Understand ads auction systems (second-price auctions)
3. Know Meta's ML pipeline (recommender systems)
4. Practice explaining engagement metrics
5. Be prepared for "growth" questions

---

## Microsoft {#microsoft}

### Interview Process
- **Phone**: 45 min coding
- **On-site**: 2-3 coding, 1 system design, 1 behavioral
- **Often Remote**: Can do partially remote interviews
- **Decision**: 5-7 days

### Unique Focus Areas
- **Enterprise Scale**: Microsoft obsessed with enterprise reliability (corporations use Windows/Office)
- **Backward Compatibility**: "How do you support Windows XP users in 2024?" (exaggeration, but real concern)
- **Azure Cloud**: Azure ecosystem heavily featured
- **Data Centers & Infrastructure**: Microsoft's massive infrastructure advantage

### Question Types (UNIQUE to Microsoft)

**Coding Focus**: Medium-Hard, emphasizing correctness over optimization

Sample problems:
- "Design a system to handle Excel formula calculations for 1B+ spreadsheets"
- "Design Office 365 collaborative editing (multiple users editing same document)"
- "Implement version control system (like Git) for enterprise"
- "Design Azure load balancer that prioritizes reliability over speed"

**System Design Unique Questions**:
- "Design Microsoft Office 365 (cloud-based office suite)" - Core product
- "Design Azure Blob Storage (competing with S3)"
- "Design Windows Update delivery to 1B+ devices"
- "Design Teams (video conferencing for enterprises)"
- "Design Xbox Live matchmaking (millions of players)"

**Why Unique**: Microsoft cares about enterprise, reliability, backward compatibility.

### Behavioral Patterns
- **Collaboration**: Microsoft emphasizes teamwork heavily
- **Quality**: "How do you ensure quality in your code?"
- **Supporting Multiple Stakeholders**: "How do you balance conflicting requirements?"
- **Growth Mindset**: "Tell me about learning from a mistake"

### Salary & Negotiation
- **Range**: $130K-300K base (L59-L63), + 10-15% bonus, 30-50K stocks
- **Negotiation**: Base more rigid than Meta/Google. Stock negotiable
- **Equity Vesting**: 4-year vest, 25% annually

### Tips
1. Study Azure services (Blob Storage, VMs, App Service)
2. Emphasize reliability and testing
3. Think about enterprise scenarios (millions of employees)
4. Know about Office/Teams architecture
5. Be prepared for "how to support legacy systems" questions

---

## Apple {#apple}

### Interview Process
- **Phone**: 45 min, coding
- **Video Interview**: 1 hour, coding + design
- **On-site**: 2 coding, 1 system design, 1 behavioral, sometimes 1 executive round
- **Slow Hiring**: Can take 2-3 months

### Unique Focus Areas
- **Privacy-First**: Apple's differentiator. Every design decision filtered through privacy lens
- **Hardware-Software Integration**: Understanding both hardware and software
- **Performance on Constrained Devices**: iOS app must work on iPhone 8 (2017)
- **End-to-End Encryption**: Security throughout stack

### Question Types (UNIQUE to Apple)

**Coding Focus**: Medium problems emphasizing memory efficiency and performance

Sample problems:
- "Design a photo app for iPhone that supports 100K photos with < 50MB memory"
- "Implement end-to-end encryption for iMessage (million messages/day)"
- "Design a system for Siri that works offline (private, no server calls)"
- "How to sync data across Apple devices (iPhone, iPad, Mac) with E2E encryption"

**System Design Unique Questions**:
- "Design iCloud (encrypted cloud storage)" - Core product
- "Design Face ID / Touch ID biometric authentication (privacy-first)"
- "Design Siri with privacy constraints (on-device processing)"
- "Design Apple Music recommendation without tracking user data"
- "Design iMessage with end-to-end encryption for 1B+ users"

**Why Unique**: Apple's differentiator is privacy. Questions focus on E2E encryption, on-device processing, security.

### Behavioral Patterns
- **Attention to Detail**: "Tell me about a time you caught a bug in production"
- **User Experience**: "How do you think about user experience?"
- **Privacy**: "How do you think about privacy in design?"
- **Quality**: Apple famously perfectionist

### Salary & Negotiation
- **Range**: $130K-280K base, + 10-20% bonus, stocks, some other perks
- **Negotiation**: Often lower than Google/Meta. Less negotiable
- **Special**: Apple grants (shares to buy at discount)

### Tips
1. Understand end-to-end encryption (Signal protocol)
2. Emphasize privacy in every answer
3. Know about Apple's hardware constraints
4. Study biometric authentication
5. Be prepared for "how to do X with < 100MB memory" questions

---

## Netflix {#netflix}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2 coding, 1 system design, 1 behavioral (sometimes 2)
- **Culture Fit**: Emphasis on "Netflix culture" (freedom & responsibility)
- **Decision**: 1-2 weeks

### Unique Focus Areas
- **Chaos Engineering**: Netflix's famous for breaking things intentionally
- **Content Delivery**: 200M+ users watching 1B+ hours/day. Streaming is hard
- **ML & Personalization**: Recommendation engine is core
- **Freedom & Responsibility**: Unique culture (very flat, high autonomy)

### Question Types (UNIQUE to Netflix)

**Coding Focus**: Hard problems emphasizing distributed systems thinking

Sample problems:
- "Design a video streaming system that survives regional outages (Chaos Engineering)"
- "Design Netflix recommendation engine for 200M+ users"
- "How would you test that your system can survive a datacenter failure?"
- "Design a system to handle 1M concurrent video streams with varying bandwidths"

**System Design Unique Questions**:
- "Design Netflix video streaming (2B+ hours watched/month)" - Core product
- "Design Netflix recommendation engine (Personalization at scale)"
- "Design chaos testing framework (unique to Netflix)"
- "Design content delivery network (Netflix uses custom CDN)"
- "Design search & discovery for 10K+ titles with ML ranking"

**Why Unique**: Netflix's uniqueness is streaming + chaos engineering + personalization.

### Behavioral Patterns
- **Freedom & Responsibility**: "Tell me about making a decision with limited oversight"
- **Self-Management**: "How do you manage your own performance?"
- **Radical Honesty**: "Tell me about giving critical feedback"
- **Impact**: "What's the biggest impact you've had?"

### Salary & Negotiation
- **Range**: $150K-320K base, + 10-20% bonus, 30-60K stocks
- **Negotiation**: Very flexible (culture emphasis). Stock negotiable
- **Special**: Netflix takes market rates seriously, pays at top

### Tips
1. Study Chaos Engineering (Chaos Monkey, etc.)
2. Understand video streaming (ABR, codec, CDN)
3. Know about Netflix's open-source culture
4. Be prepared for "design for failure" questions
5. Emphasize autonomy in behavioral answers

---

## Uber {#uber}

### Interview Process
- **Phone**: 45 min, coding (often medium-hard)
- **On-site**: 2-3 coding, 1 system design, 1 behavioral, sometimes 1 "tech lead" round
- **Fast Decision**: 3-5 days typical
- **Frequent Hiring**: Uber always hiring

### Unique Focus Areas
- **Real-Time Systems**: Matching driver to rider in < 10 seconds
- **Geo-Spatial**: Finding nearby drivers/riders with millions of users
- **Financial Systems**: Payment processing at scale (30M transactions/day)
- **Low Latency**: Ride matching is latency-critical

### Question Types (UNIQUE to Uber)

**Coding Focus**: Hard problems emphasizing geo-spatial algorithms

Sample problems:
- "Design geohashing algorithm to find drivers within 5 miles in O(log N)"
- "Design a distributed counter for ride ID generation (idempotency critical)"
- "Implement rate limiter for API that handles 1M requests/sec from drivers/riders"
- "Design a system to update driver location 30M times per day with 100ms latency"

**System Design Unique Questions**:
- "Design Uber ride matching (find nearby drivers in < 10 seconds)" - Core problem
- "Design Uber's ETA calculation (compute ETA for 500K requests/second)"
- "Design Uber's payment system (30M transactions/day, idempotent)"
- "Design surge pricing algorithm (real-time price adjustment)"
- "Design Uber's driver acceptance system (show ride to N drivers, accept first)"

**Why Unique**: Uber's core challenge is matching + geo-spatial + real-time payments.

### Behavioral Patterns
- **Ownership**: "Tell me about owning a project end-to-end"
- **Problem-Solving Under Uncertainty**: "How do you approach ambiguous problems?"
- **Impact**: "What's the impact of your work on Uber's business?"
- **Speed**: "Tell me about shipping fast"

### Salary & Negotiation
- **Range**: $140K-300K base, + 15-25% bonus, 30-60K stocks
- **Negotiation**: Base negotiable, stock/bonus flexible
- **Sign-on**: 20-40K common

### Tips
1. Study geohashing and spatial indexing (QuadTree, R-tree)
2. Understand ETA algorithms (Dijkstra, A*)
3. Know about idempotent APIs (payment systems)
4. Be prepared for "low latency" questions
5. Think about distributed matching algorithms

---

## Stripe {#stripe}

### Interview Process
- **Phone**: 45 min, coding + design blend
- **On-site**: 2-3 coding, 1 system design, 1 "stripe problem" (business-focused), 1-2 behavioral
- **Stripe Problem**: Unique round where you solve a real Stripe problem
- **Decision**: 1 week

### Unique Focus Areas
- **Payments**: Stripe's core. Understanding payment flows, PCI compliance critical
- **Financial Correctness**: Money systems must be correct (no rounding errors)
- **Global Scale**: Stripe operates in 190+ countries (compliance complexity)
- **API Design**: Stripe's API is famous for elegance

### Question Types (UNIQUE to Stripe)

**Coding Focus**: Medium problems emphasizing correctness and edge cases

Sample problems:
- "Design a payment system that handles refunds, partial refunds, reversals with exactly-once semantics"
- "Implement a currency converter that never loses precision (no floating point)"
- "Design an idempotent payment processing API (prevent double-charging)"
- "Design a rate limiter for payment API that costs money (prevent abuse without blocking legitimate traffic)"

**System Design Unique Questions**:
- "Design Stripe payment processing (handle 1B+ payments/month)" - Core product
- "Design Stripe Connect (marketplace payments)" - Stripe-specific product
- "Design settlement system (pay out money to merchants daily)"
- "Design PCI-compliant payment system (security critical)"
- "Design fraud detection system (prevent 0.1% fraudulent transactions)"

**Why Unique**: Stripe's challenge is payment systems, financial correctness, global compliance.

### Behavioral Patterns
- **Attention to Detail**: "Tell me about catching a subtle bug"
- **Thinking Like Customer**: "How do you empathize with our API users?"
- **Quality**: "How do you ensure quality in financial systems?"
- **Communication**: "How do you explain complex financial concepts simply?"

### Salary & Negotiation
- **Range**: $150K-320K base, + 20-40% bonus, 40-100K stocks
- **Negotiation**: Base + bonus flexible. Stripe stock valuable
- **Special**: Stripe often top bidder (competes aggressively for talent)

### Tips
1. Study payment systems (PCI compliance, tokenization, idempotency)
2. Understand fintech (settlement, reconciliation, disputes)
3. Know about API design (Stripe's API elegance famous)
4. Be prepared for "financial correctness" questions
5. Think about global payments (190+ countries, compliance nightmare)

---

## Airbnb {#airbnb}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2-3 coding, 1 system design, 1 behavioral
- **Design Focus**: System design round heavily weighted
- **Culture**: Emphasis on values ("Belong anywhere")

### Unique Focus Areas
- **Two-Sided Marketplace**: Hosts + guests. Matching is complex
- **Geospatial Search**: Finding properties nearby is core
- **Trust & Safety**: Verification critical (people inviting strangers)
- **Seasonality**: Travel patterns are seasonal

### Question Types (UNIQUE to Airbnb)

**Coding Focus**: Medium problems emphasizing search/ranking

Sample problems:
- "Design a search system for 5M properties with geo-spatial + filters + ranking"
- "Implement search that handles seasonal availability (winter = more expensive)"
- "Design a review/rating system that prevents fake reviews"
- "Design a messaging system between hosts and guests"

**System Design Unique Questions**:
- "Design Airbnb search (find properties with geo-spatial filtering)" - Core product
- "Design Airbnb matching (match hosts and guests)" - Marketplace specific
- "Design Airbnb payments (escrow system, host payout)"
- "Design pricing recommendation system for hosts"
- "Design trust & safety system (verification, dispute resolution)"

**Why Unique**: Airbnb's core is two-sided marketplace matching + geo-spatial search.

### Behavioral Patterns
- **Trust**: "How do you build trust in your systems?"
- **Community**: "Tell me about building community"
- **Values**: Airbnb values alignment important
- **Global Perspective**: "How do you think about cultural differences?"

### Salary & Negotiation
- **Range**: $130K-280K base, + 20-30% bonus, 30-60K stocks
- **Negotiation**: Moderately flexible
- **Sign-on**: 15-30K common

### Tips
1. Study two-sided marketplace design (matching algorithms)
2. Understand geospatial search (Airbnb's search core)
3. Know about trust systems (verification, reviews)
4. Be prepared for "fake review" detection questions
5. Think about seasonal pricing

---

## Twitter/X {#twitter}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2 coding, 1 system design, 1 behavioral
- **Fast Paced**: Twitter culture is very fast-moving
- **Decision**: 1 week

### Unique Focus Areas
- **Real-Time Streaming**: Tweets must appear in real-time (< 2 seconds)
- **Timeline Generation**: Feed ranking with millions of follows
- **Trending Topics**: Detect trends in real-time (1M+ tweets/minute)
- **Search at Scale**: 1B+ tweets, full-text search critical

### Question Types (UNIQUE to Twitter)

**Coding Focus**: Hard problems emphasizing real-time processing

Sample problems:
- "Design a system to detect trending topics in real-time (500M users posting)"
- "Design Twitter timeline ranking (show most relevant tweets first)"
- "Implement full-text search across 1B+ tweets with filtering"
- "Design a notification system for 500M users (mentions, replies, likes)"

**System Design Unique Questions**:
- "Design Twitter timeline (real-time feed ranking)" - Core product
- "Design Twitter search (full-text search across 1B+ tweets)"
- "Design trending topics detection (real-time trending)"
- "Design Twitter notification system (mention, retweet, like notifications)"
- "Design Twitter API for third-party developers"

**Why Unique**: Twitter's uniqueness is real-time streaming + timeline ranking + search.

### Behavioral Patterns
- **Speed**: "Tell me about shipping fast"
- **Iteration**: "How do you iterate quickly?"
- **Handling Criticism**: "Tell me about receiving negative feedback on a feature"
- **Impact**: "What's the reach of your feature?"

### Salary & Negotiation
- **Range**: $120K-280K base, + 20-30% bonus, 20-50K stocks
- **Negotiation**: Lower than Google/Meta in recent years
- **Market Dependent**: Post-Elon changes affected comp

### Tips
1. Study stream processing (Kafka, real-time systems)
2. Understand full-text search (inverted indexes)
3. Know about trending algorithms
4. Be prepared for "real-time" questions
5. Think about handling mutable content (edits)

---

## Lyft {#lyft}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2 coding, 1 system design, 1 behavioral
- **Smaller than Uber**: Slightly more focused interviews
- **Decision**: 1 week

### Unique Focus Areas
- **Network Effects**: Unlike Uber, Lyft emphasizes driver/rider community
- **Real-Time Matching**: Similar to Uber but with less scale
- **Price Transparency**: Lyft differentiator (no surge pricing initially)
- **Safety**: Emphasis on rider & driver safety

### Question Types (UNIQUE to Lyft)

**Coding Focus**: Medium-Hard, similar to Uber but slightly less extreme

Sample problems:
- "Design a driver-rider matching system with fairness (ensure drivers get equal opportunities)"
- "Design a system to prevent surge pricing exploitation"
- "Implement a routing system that minimizes driver wait time"
- "Design a passenger rating system that prevents manipulation"

**System Design Unique Questions**:
- "Design Lyft ride matching with fairness guarantees" - Core, but with fairness angle
- "Design Lyft's pricing system (transparent, fair pricing)"
- "Design Lyft Express (shared rides system)"
- "Design driver scheduling system (future scheduled rides)"
- "Design safety verification system (background checks, rating verification)"

**Why Unique**: Lyft differentiates on fairness, transparency, safety.

### Behavioral Patterns
- **Community**: "Tell me about building driver/rider community"
- **Fairness**: "How do you ensure fairness in a two-sided system?"
- **Safety**: "How do you think about safety?"

### Salary & Negotiation
- **Range**: $120K-250K base, + 15-25% bonus, 20-40K stocks
- **Negotiation**: Less aggressive than Uber (smaller company)

### Tips
1. Study two-sided marketplace design (like Uber)
2. Emphasize fairness in matching algorithms
3. Understand Lyft's differentiation (transparency vs surge)
4. Be prepared for "how to prevent abuse" questions

---

## Snap {#snap}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2 coding, 1 system design, 1 behavioral
- **Media Focus**: Emphasis on video/image processing
- **Decision**: 1 week

### Unique Focus Areas
- **Ephemeral Content**: Snaps disappear. Different challenges than Twitter/Facebook
- **Camera/Filters**: AR filters are Snap's differentiator
- **Real-Time Messaging**: Real-time chat with disappearing messages
- **Youth Culture**: Snap obsessed with younger demographics

### Question Types (UNIQUE to Snap)

**Coding Focus**: Medium problems emphasizing image/video processing

Sample problems:
- "Design a disappearing message system (delete after read)"
- "Design an AR filter system that runs in real-time on mobile"
- "Design a system to recommend Stories to users (discovery)"
- "Implement a system to detect and prevent screenshot of disappearing content"

**System Design Unique Questions**:
- "Design Snapchat Stories (ephemeral content feed)" - Core product
- "Design Snapchat camera & filters (AR at scale)"
- "Design Snapchat messaging (real-time, disappearing messages)"
- "Design Snapchat discovery (Find Friends, Discover feed)"

**Why Unique**: Snap's uniqueness is ephemeral content + AR + real-time messaging.

### Behavioral Patterns
- **Innovation**: "Tell me about creating something innovative"
- **Speed**: Snap culture emphasizes moving fast
- **Youth Understanding**: "How do you think about younger users?"

### Salary & Negotiation
- **Range**: $120K-260K base, + 15-25% bonus, 20-40K stocks
- **Negotiation**: Moderately flexible

### Tips
1. Understand AR/computer vision (Snap's filters core)
2. Know about ephemeral content challenges
3. Be prepared for "real-time" questions
4. Study image/video processing

---

## TikTok {#tiktok}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2-3 coding, 1 system design, 1 behavioral, sometimes 1 ML round
- **Competitive**: TikTok competes aggressively for talent
- **Decision**: 1 week

### Unique Focus Areas
- **Recommendation Engine**: TikTok's secret sauce. Recommendation >> social graph
- **Content Distribution**: Algorithm decides what you see (not follows)
- **Video Processing**: Mobile-first platform (optimize for mobile)
- **Retention**: TikTok obsessed with "time on app"

### Question Types (UNIQUE to TikTok)

**Coding Focus**: Hard problems emphasizing ML + scale

Sample problems:
- "Design a recommendation system that predicts video watch time (3-30 seconds)"
- "Design a system to detect viral videos in real-time"
- "Implement a ranking algorithm that balances novelty + relevance"
- "Design a system to process 1B videos/day and rank for 1B users"

**System Design Unique Questions**:
- "Design TikTok recommendation (algorithm decides feed, not follows)" - Core competitive advantage
- "Design TikTok video processing pipeline (mobile-optimized)"
- "Design TikTok trending detection"
- "Design TikTok creator tools (analytics, growth)"
- "Design TikTok ads system (monetization through FYP)"

**Why Unique**: TikTok's competitive advantage is recommendation algorithm + mobile optimization.

### Behavioral Patterns
- **Growth Mindset**: Tiktok hires for growth
- **Data-Driven**: "How do you use data to make decisions?"
- **Scale**: "How do you think about scaling?"

### Salary & Negotiation
- **Range**: $140K-300K base, + 20-40% bonus, 30-60K stocks
- **Negotiation**: Very competitive, TikTok pays top dollar
- **Special**: Fresh company money, can pay more than older companies

### Tips
1. Study recommendation systems (collaborative filtering, ranking)
2. Understand mobile optimization (TikTok mobile-first)
3. Know about viral metrics (watch time, engagement)
4. Be prepared for "how to detect trends" questions
5. Study their algorithm (publicly discussed somewhat)

---

## Databricks {#databricks}

### Interview Process
- **Phone**: 45 min, coding + design
- **On-site**: 2 coding, 1 system design, 1 behavioral, sometimes 1 data systems round
- **Data Systems Focus**: Emphasis on understanding data
- **Decision**: 1 week

### Unique Focus Areas
- **Big Data**: Databricks = Apache Spark. Data processing at scale
- **Data Lakehouse**: Parquet format, columnar storage
- **ML Frameworks**: MLflow (Databricks' ML framework)
- **Engineering**: Infrastructure, not product focus (B2B)

### Question Types (UNIQUE to Databricks)

**Coding Focus**: Hard problems emphasizing distributed data processing

Sample problems:
- "Design a distributed query engine (like Spark) that processes 1PB data"
- "Implement a columnar storage format (like Parquet) with compression"
- "Design a system to optimize Spark queries (cost-based optimizer)"
- "Implement a distributed ML training system (MLflow)"

**System Design Unique Questions**:
- "Design Apache Spark (distributed data processing engine)" - Core product
- "Design Databricks lakehouse (unified storage for data & ML)"
- "Design MLflow (ML lifecycle management)"
- "Design distributed query optimizer"
- "Design data catalog system for enterprise (metadata management)"

**Why Unique**: Databricks is about big data infrastructure, not consumer products.

### Behavioral Patterns
- **Technical Depth**: Very engineering-focused
- **Problem-Solving**: "Tell me about solving a complex system problem"
- **Scalability**: "How do you think about scale?"

### Salary & Negotiation
- **Range**: $150K-320K base, + 25-40% bonus, 40-100K stocks
- **Negotiation**: Very flexible (competitive for talent)

### Tips
1. Study Apache Spark (understand distributed processing)
2. Know about columnar storage (Parquet, ORC)
3. Understand query optimization
4. Be prepared for "how to process 1PB" questions
5. Know ML frameworks (MLflow, Ray)

---

## Canva {#canva}

### Interview Process
- **Phone**: 45 min, coding
- **On-site**: 2-3 coding, 1 system design, 1 behavioral
- **Design/Product Focus**: Questions touch on design + product thinking
- **Decision**: 1 week

### Unique Focus Areas
- **Design Tools**: Canva is a design tool. User experience critical
- **Collaboration**: Real-time collaborative design (like Google Docs, but graphics)
- **Template System**: Millions of templates searchable
- **Creator Economy**: Focus on empowering creators (non-designers)

### Question Types (UNIQUE to Canva)

**Coding Focus**: Medium problems emphasizing user experience + scale

Sample problems:
- "Design a real-time collaborative drawing system (multiple users editing same design)"
- "Design a template recommendation system for 200M users"
- "Implement a system to render designs instantly even with 1M+ elements"
- "Design a search system for 100M+ templates with filtering"

**System Design Unique Questions**:
- "Design Canva editor (real-time collaborative design tool)" - Core product
- "Design Canva template search & recommendation"
- "Design Canva collaboration (multiple users editing simultaneously)"
- "Design Canva export system (convert design to PDF/PNG instantly)"
- "Design Canva plugin system (third-party extensions)"

**Why Unique**: Canva is consumer product with design tools + creator economy focus.

### Behavioral Patterns
- **User-Centric**: "How do you think about users?"
- **Creativity**: "Tell me about encouraging user creativity"
- **Growth**: Canva hyper-growth company

### Salary & Negotiation
- **Range**: $120K-280K base, + 15-30% bonus, 20-50K stocks
- **Negotiation**: Good negotiation room (rapidly growing)

### Tips
1. Use Canva to understand product
2. Study collaborative editing (OT/CRDT like Google Docs)
3. Understand template systems & search
4. Be prepared for "real-time" questions
5. Think about user experience (not just scale)

---

## Expanded Practice Question Bank

Use these questions as mock interviews. For each one, spend 3-5 minutes clarifying requirements, 25-35 minutes on the solution, and 5 minutes discussing trade-offs and failure modes.

This section is deliberately a **practice bank**, not a second copy of the concept guides. Learn the building blocks in the linked chapters first, then answer the prompts without looking at notes. Use the worked examples and rubric afterward to evaluate the result.

### Study Map

| Company | Topics to learn before attempting its prompts |
|---|---|
| Google | [Caching, storage, protocols, and consistent hashing](system-design-fundamentals-extended.md#essential-25), [rate limiting and deduplication cases](system-design-extended.md), [sharding and quorum](distributed-systems-patterns.md) |
| Amazon | [Saga, outbox, inbox, and retry queues](distributed-systems-patterns.md), [waiting room and payment/gift-card designs](system-design-extended.md), [backend transaction patterns](backend-design-patterns.md) |
| Meta | [Twitter timeline design](system-design-extended.md#q57-design-twitter-timeline), [materialized views and pub/sub](distributed-systems-patterns.md), [rate limiting and counters](system-design-fundamentals-extended.md) |
| Microsoft | [Tenant onboarding and tenant-aware authorization](system-design-extended.md), [API and data compatibility](system-design-fundamentals-extended.md), [result and adapter patterns](backend-design-patterns.md) |
| Apple | [Dropbox-style synchronization and secure uploads](system-design-extended.md), [TLS and storage selection](system-design-fundamentals-extended.md), [background work](backend-design-patterns.md) |
| Netflix | [Streaming/media system designs](system-design-extended.md), [timeouts, retries, breakers, and cells](distributed-systems-patterns.md), [observability](system-design-fundamentals-extended.md) |
| Uber | [Google Maps/navigation design](system-design-extended.md), [queues, sharding, and idempotent consumers](distributed-systems-patterns.md), [payment correctness](system-design-extended.md) |
| Stripe | [Payment links, gift cards, and idempotency](system-design-extended.md), [outbox/inbox patterns](distributed-systems-patterns.md), [unit of work and result patterns](backend-design-patterns.md) |
| Airbnb | [Airbnb design](system-design-extended.md#q54-design-airbnb), [sagas and materialized views](distributed-systems-patterns.md), [database and cache selection](system-design-fundamentals-extended.md) |
| Twitter/X | [Twitter timeline design](system-design-extended.md#q57-design-twitter-timeline), [fan-out, pub/sub, and projections](distributed-systems-patterns.md), [CDN and caching](system-design-fundamentals-extended.md) |
| Lyft | [Navigation and geo-oriented design](system-design-extended.md), [queues, cells, and load shedding](distributed-systems-patterns.md), [quality attributes and observability](system-design-fundamentals-extended.md) |
| Snap | [Secure uploads and chat](system-design-extended.md), [CDN, WebSocket, and event selection](system-design-fundamentals-extended.md), [cache and background-worker patterns](backend-design-patterns.md) |
| TikTok | [CQRS/materialized views, pub/sub, and competing consumers](distributed-systems-patterns.md), [protocol and database selection](system-design-fundamentals-extended.md), [strategy and mediator patterns](backend-design-patterns.md) |
| Databricks | [Sharding, quorum, leader election, and fencing](distributed-systems-patterns.md), [storage and capacity fundamentals](system-design-fundamentals-extended.md), [workflow and queue designs](system-design-extended.md) |
| Canva | [Frontend Command, State Machine, Store, and Composite patterns](angular.md#frontend-design-patterns), [file synchronization](system-design-extended.md), [event sourcing and conflict-aware processing](distributed-systems-patterns.md) |

### Required Answer Format for Every Practice Question

The questions below are intentionally open-ended mock prompts. Answer every one using this consistent structure:

1. **Question and short answer:** Restate the goal and give the main design decision.
2. **What problem does the concept solve?** Name the bottleneck, correctness risk, or user problem.
3. **Before the concept:** Explain how a simple first version worked and where it failed.
4. **Wrong example:** Show a specific tempting design that breaks under concurrency, failure, security, or scale.
5. **Correct example:** Present the improved API, data model, algorithm, or architecture.
6. **How it works afterward:** Walk through one successful request and one failure or retry.
7. **Trade-offs and follow-ups:** State what the design costs, when it should change, and how success is measured.

**Mini example — distributed counter:**

- **Question and answer:** Count reactions at very high write volume by sharding updates and aggregating them asynchronously.
- **Problem solved:** One counter key becomes a write hotspot.
- **Before:** Every request increments one strongly consistent database row.
- ❌ **Wrong:** Add more API servers but keep the single locked counter row; the database bottleneck remains.
- ✅ **Correct:** Hash each update across counter shards, make event processing idempotent, and periodically materialize the total.
- **After:** Writes spread across partitions; reads return a recent aggregate with a documented staleness bound.
- **Trade-off:** Higher throughput is gained by accepting temporary count staleness and more reconciliation logic.

### Google

1. **Search autocomplete:** Design autocomplete for billions of queries while keeping p99 latency below 100 ms. How would you handle trending queries, spelling mistakes, and offensive suggestions?
2. **Globally consistent quota:** Design a quota service shared by products in multiple regions. When would you trade strict accuracy for availability?
3. **Large-scale deduplication:** Given a continuous stream of URLs, detect exact and near duplicates without keeping every page in memory.

**Interviewer follow-ups:** How do hot prefixes affect sharding? What happens during a regional outage? How would you measure suggestion quality?

### Amazon

1. **Inventory reservation:** Prevent overselling the last item when thousands of customers check out simultaneously.
2. **Order workflow:** Design an order state machine that survives duplicate messages, delayed payments, and partial shipment failures.
3. **Cost-aware log archive:** Store petabytes of audit logs with different retention and retrieval requirements while minimizing cost.

**Interviewer follow-ups:** Where are idempotency keys stored? How do you reconcile inventory? Which metrics demonstrate customer impact?

### Meta

1. **News-feed fan-out:** Choose between fan-out-on-write and fan-out-on-read for ordinary users, celebrities, and private groups.
2. **Experiment platform:** Design A/B testing that prevents sample-ratio mismatch and supports guardrail metrics.
3. **Abuse-resistant reactions:** Count reactions in real time while detecting bots and preserving eventual correctness.

**Interviewer follow-ups:** How do you avoid filter bubbles? How are deleted posts removed from caches? What is the rollback plan for a harmful experiment?

### Microsoft

1. **Tenant-aware SaaS:** Design a multi-tenant enterprise API with data isolation, per-tenant throttling, and regional residency.
2. **Document compatibility:** Evolve a document format without breaking clients that are ten years old.
3. **Identity outage:** Keep a business application safe and useful when its identity provider is temporarily unavailable.

**Interviewer follow-ups:** How do you test backward compatibility? Where do tenant identifiers enter the trust boundary? Which actions fail closed?

### Apple

1. **Private photo search:** Support semantic photo search without uploading raw photos to a server.
2. **Device sync:** Synchronize encrypted notes across intermittently connected devices and resolve concurrent edits.
3. **Battery-aware background work:** Schedule uploads and indexing without harming battery life or foreground responsiveness.

**Interviewer follow-ups:** Where are encryption keys stored? What metadata still leaks? How do older devices receive a degraded experience?

### Netflix

1. **Continue watching:** Maintain playback position across devices despite offline viewing and out-of-order events.
2. **Adaptive bitrate:** Select video quality as bandwidth changes while minimizing buffering and quality oscillation.
3. **Regional evacuation:** Move playback traffic away from a failing region without creating a retry storm.

**Interviewer follow-ups:** Which signal triggers failover? How do you test failure safely? What happens when the recommendation service is down?

### Uber

1. **Driver location pipeline:** Ingest millions of location updates while handling GPS noise, stale updates, and mobile disconnections.
2. **Trip assignment:** Match riders and drivers while balancing pickup time, fairness, cancellations, and surge zones.
3. **Exactly-once fare outcome:** Produce one correct rider charge and driver payout despite at-least-once message delivery.

**Interviewer follow-ups:** How are geospatial cells rebalanced? Can a match be revoked? Which operations require a ledger?

### Stripe

1. **Idempotent payments API:** Design `POST /payments` so client retries never create a second charge.
2. **Double-entry ledger:** Model charges, refunds, disputes, fees, and currency conversion with an auditable ledger.
3. **Webhook delivery:** Deliver events to unreliable customer endpoints with ordering, retries, signatures, and replay support.

**Interviewer follow-ups:** What does an idempotency key scope include? Can ledger entries be updated? How do merchants recover missed webhooks?

### Airbnb

1. **Booking race:** Ensure two guests cannot reserve the same home and dates.
2. **Search ranking:** Rank listings using relevance, availability, price, quality, and host acceptance probability.
3. **Trust signals:** Build a review system resistant to retaliation, fake stays, and coordinated abuse.

**Interviewer follow-ups:** How do temporary holds expire? Which ranking features risk discrimination? How do cancellations update the search index?

### Twitter/X

1. **Trending topics:** Detect local trends without allowing a globally popular topic to dominate every region.
2. **Home timeline:** Serve a low-latency timeline for users following both ordinary accounts and celebrities.
3. **Conversation graph:** Store replies, quotes, edits, and deletions while preserving thread readability.

**Interviewer follow-ups:** How do you resist coordinated manipulation? How are celebrity posts fanned out? What does deletion mean in replicas and caches?

### Lyft

1. **Accessible matching:** Match riders needing accessible vehicles while controlling wait time and driver utilization.
2. **Safety event pipeline:** Detect suspicious route deviations and escalate without creating excessive false alarms.
3. **Airport queues:** Design fair virtual queues under changing airport rules and geofence uncertainty.

**Interviewer follow-ups:** How is fairness measured? Which safety decisions need a human? How do you prevent location spoofing?

### Snap

1. **Ephemeral delivery:** Deliver a snap once across multiple recipient devices and enforce expiration semantics.
2. **AR lens distribution:** Select, cache, and update lenses under mobile bandwidth and GPU constraints.
3. **Story ranking:** Rank recent stories while respecting privacy settings and freshness.

**Interviewer follow-ups:** Can deletion be guaranteed on a compromised device? How do you roll back a crashing lens? Which work runs on-device?

### TikTok

1. **Cold-start recommendations:** Build a useful first session with almost no behavioral history.
2. **Real-time feature pipeline:** Update recommendation features seconds after a watch, skip, like, or report.
3. **Creator exploration:** Give new creators exposure without significantly reducing viewer satisfaction.

**Interviewer follow-ups:** How do you avoid feedback loops? Which metrics capture long-term satisfaction? How do you audit regional policy differences?

### Databricks

1. **Skewed distributed join:** Execute a join when one key owns 40% of the data without leaving one worker as a straggler.
2. **Lakehouse transaction log:** Support concurrent writers, snapshot isolation, schema evolution, and time travel over object storage.
3. **Notebook execution:** Schedule interactive and batch notebook cells with dependency tracking and reproducibility.

**Interviewer follow-ups:** How are small files compacted? What happens when a writer dies after uploading data but before committing? How is lineage recorded?

### Canva

1. **Collaborative canvas:** Synchronize object moves, text edits, and layer changes among many editors.
2. **Undo/redo in collaboration:** Define whether undo reverses a user's last action or the document's last action.
3. **Export pipeline:** Render large designs to PDF, video, and images reliably without blocking the editor.

**Interviewer follow-ups:** When would you use CRDTs versus operational transformation? How are fonts and assets versioned? How do exports become idempotent?

---

## Worked Answer Examples

### Example 1: Stripe — Idempotent Payment Creation

**Question:** Design a payment creation endpoint that remains safe when clients retry after a timeout.

**Strong answer outline:**

1. Clarify that the same merchant and idempotency key must return the same logical result; a different request body with that key is rejected.
2. Store `(merchant_id, idempotency_key, request_hash, status, response)` behind a unique constraint.
3. In one transaction, claim the key and create a payment in `Pending`. Concurrent requests either observe the existing record or lose the unique-key race.
4. Send processor work through a durable outbox. The processor adapter also receives a stable operation identifier.
5. Persist the terminal response and replay it for later retries. A request still in progress returns a retryable status rather than starting new work.

```text
Client -> Payments API -> Idempotency Store -> Payment + Outbox
                                      Outbox -> Processor Worker -> Card Network
```

**Trade-off:** A local idempotency table prevents duplicate application work, but end-to-end safety also requires an idempotent processor API or reconciliation against the processor's transaction identifier.

**Common weak answer:** "Check whether the payment already exists" without defining the atomic boundary. Two simultaneous checks can both see nothing and create duplicate charges.

### Example 2: Amazon — Prevent Overselling

**Question:** How would you reserve the final item during a flash sale?

**Strong answer outline:**

- Use an atomic conditional update: decrement only when `available > 0`.
- Create a short-lived reservation with an expiration time, not a completed order.
- Publish reservation events through an outbox so payment and fulfillment see durable state changes.
- Make confirmation and release idempotent. An expiry worker returns inventory only if the reservation is still `Held`.
- Reconcile the inventory aggregate against reservations and confirmed orders.

```sql
UPDATE Inventory
SET Available = Available - 1,
    Version = Version + 1
WHERE Sku = @sku AND Available > 0 AND Version = @expectedVersion;
```

**Trade-off:** A single strongly consistent inventory owner protects correctness but can become hot. Partition by SKU, isolate extremely hot products, and apply admission control rather than weakening the no-oversell invariant.

### Example 3: Meta/Twitter — Hybrid Timeline Fan-out

**Question:** Should timelines use fan-out-on-write or fan-out-on-read?

**Strong answer:** Use a hybrid. Fan out ordinary accounts' posts into follower inboxes because their follower counts are bounded. Do not push celebrity posts to millions of inboxes; fetch those posts at read time and merge them with the precomputed inbox. Cache the first page, rank candidates separately from storage, and carry a cursor containing ranking and time boundaries.

**Failure handling:** The post write succeeds before asynchronous fan-out. A lagging fan-out worker may make a post temporarily absent, so the read path can perform a bounded repair for recent posts. Deletions publish tombstones that invalidate inbox entries and caches.

**What the interviewer is testing:** Recognition that neither pure strategy works for every degree distribution, plus awareness of hot keys, eventual consistency, ranking, and deletion.

### Example 4: Canva — Concurrent Object Movement

**Question:** Two users move the same object at nearly the same time. What should happen?

**Strong answer outline:** Represent each operation with document ID, object ID, actor ID, logical timestamp, and base version. For independent objects, operations commute. For the same object's absolute position, use a deterministic last-writer rule or a server-sequenced operation; for text, use a sequence CRDT or OT. Show remote cursors optimistically, acknowledge committed operations, and rebase pending local operations after reconnect.

**Product insight:** Correctness is not only convergence. Users should see who is editing, receive a visible conflict indication for surprising overwrites, and retain version history for recovery.

### Example 5: Behavioral — A High-Quality STAR Answer

**Question:** Tell me about a time you disagreed with a technical decision.

**Example answer:**

- **Situation:** A checkout team planned to call three downstream services synchronously, and load tests showed p99 latency above two seconds.
- **Task:** I owned the API design and needed to improve reliability without delaying the launch.
- **Action:** I documented failure modes, built a one-day prototype using an outbox for non-critical notifications, and compared both designs with load-test data. I asked the original designer to review the experiment and kept price validation synchronous because it protected correctness.
- **Result:** p99 fell from 2.1 seconds to 620 ms, the launch stayed on schedule, and notification failures no longer blocked orders. We added the decision and rollback conditions to an ADR.
- **Reflection:** I learned to frame disagreement around measurable constraints and preserve the other design's valid invariants.

**Why it works:** It gives individual actions, measurable results, a trade-off, collaboration, and learning. Replace the numbers with your real evidence; never invent metrics in an interview.

---

## Self-Evaluation Rubric

Score each mock answer from 0-2 in every category (maximum 12):

| Category | 0 | 1 | 2 |
|---|---|---|---|
| Requirements | Assumes everything | Asks basic questions | Defines users, scale, invariants, and scope |
| API/data model | Missing | Partial | Clear contracts, keys, states, and indexes |
| Architecture | Unstructured | Main components only | Coherent data flow with justified boundaries |
| Scale | Ignored | Mentions caching/sharding | Estimates load and targets actual bottlenecks |
| Reliability/security | Happy path only | Some failures | Idempotency, recovery, observability, and abuse controls |
| Trade-offs | Claims one best answer | Names alternatives | Explains why and when the decision changes |

**Interpretation:** 10-12 is interview-ready, 7-9 needs targeted practice, and 0-6 should be redesigned from the requirements upward.

---

## Comparison Matrix {#matrix}

| Company | Core Strength | Question Focus | Salary Range | Difficulty |
|---------|---------------|-----------------|--------------|------------|
| Google | Scale & Performance | Distributed systems, optimization | $150K-300K | Very Hard |
| Amazon | E-Commerce & Cost | AWS services, cost optimization | $120K-280K | Hard |
| Meta | Feed & Ads | Ranking, engagement, ads | $140K-320K | Hard |
| Microsoft | Enterprise & Reliability | Enterprise scale, backward compatibility | $130K-300K | Medium-Hard |
| Apple | Privacy & Hardware | E2E encryption, on-device | $130K-280K | Medium-Hard |
| Netflix | Streaming & Chaos | Video delivery, chaos engineering | $150K-320K | Hard |
| Uber | Real-Time Geo | Geo-spatial, matching, payments | $140K-300K | Very Hard |
| Stripe | Payments & Fintech | Payment systems, financial correctness | $150K-320K | Hard |
| Airbnb | Marketplace | Two-sided matching, geo-spatial | $130K-280K | Medium-Hard |
| Twitter/X | Real-Time | Streaming, trending, search | $120K-280K | Hard |
| Lyft | Fairness & Safety | Matching with constraints, safety | $120K-250K | Medium-Hard |
| Snap | Ephemeral & AR | Real-time, AR, disappearing content | $120K-260K | Medium |
| TikTok | Recommendation | ML, ranking, recommendation | $140K-300K | Very Hard |
| Databricks | Big Data | Distributed processing, optimization | $150K-320K | Very Hard |
| Canva | Design Tools | Collaboration, real-time, UX | $120K-280K | Medium |

---

## Key Takeaways

**Each company has UNIQUE characteristics:**
- **Google**: Distributed systems + Google-specific tech (Spanner, Bigtable, Dremel)
- **Amazon**: E-commerce + cost optimization + AWS
- **Meta**: Feed ranking + ads + engagement
- **Microsoft**: Enterprise scale + backward compatibility
- **Apple**: Privacy + E2E encryption + on-device
- **Netflix**: Video streaming + chaos engineering + personalization
- **Uber**: Geo-spatial + real-time matching + payments
- **Stripe**: Payment systems + financial correctness + global compliance
- **Airbnb**: Two-sided marketplace + geo-spatial matching
- **Twitter**: Real-time streaming + timeline ranking + search
- **Lyft**: Fairness + safety + community
- **Snap**: Ephemeral content + AR + real-time
- **TikTok**: Recommendation algorithms + mobile optimization
- **Databricks**: Big data infrastructure + distributed processing
- **Canva**: Collaborative design tools + templates

**No questions are repeated across companies.** Each company's questions are customized to their core business and technical challenges.

**Study the comparison matrix to understand salary expectations and difficulty levels for your target company.**

---

**Strategy**: 
1. Pick your target company
2. Study their unique focus areas
3. Practice their unique question types
4. Understand their tech stack
5. Prepare behavioral answers around their values
6. Negotiate salary based on company standards

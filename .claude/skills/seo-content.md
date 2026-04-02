# SEO Content Skill — Meta Tags, OG, Schema.org, Next.js Metadata

## Meta Tags Template

```html
<!-- Title: 50-60 chars. Primary keyword near the front. Brand at end. -->
<title>Primary Keyword: Value Proposition | Brand Name</title>

<!-- Description: 150-160 chars. Primary keyword in first 20 words. Include a CTA. -->
<meta name="description" content="Discover [primary keyword] that [benefit]. [Secondary keyword] for [target audience]. [CTA: Get started free, Learn more, etc.]" />

<!-- Canonical: always specify, prevents duplicate content penalties -->
<link rel="canonical" href="https://example.com/exact-path" />

<!-- Robots: only add if you need non-default behavior -->
<meta name="robots" content="index, follow" />
<!-- For paginated pages beyond page 1: -->
<meta name="robots" content="noindex, follow" />
<!-- For admin/private pages: -->
<meta name="robots" content="noindex, nofollow" />

<!-- Viewport (already in Next.js layout by default) -->
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

## Open Graph Tags Template

```html
<!-- og:type: website (homepage), article (blog), product, profile -->
<meta property="og:type" content="article" />
<meta property="og:title" content="Primary Keyword: Value Proposition | Brand" />
<meta property="og:description" content="Social-optimized description. Can be slightly different from meta description — optimized for sharing engagement rather than SERP." />
<meta property="og:url" content="https://example.com/exact-path" />

<!-- OG Image: 1200x630px. Text must be readable at small size. -->
<meta property="og:image" content="https://example.com/images/og/page-name.jpg" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:alt" content="Descriptive alt text for the OG image" />
<meta property="og:image:type" content="image/jpeg" />

<meta property="og:site_name" content="Brand Name" />
<meta property="og:locale" content="en_US" />

<!-- Article-specific (when og:type is "article") -->
<meta property="article:published_time" content="2026-04-02T10:00:00Z" />
<meta property="article:modified_time" content="2026-04-02T12:00:00Z" />
<meta property="article:author" content="https://example.com/author/john-doe" />
<meta property="article:section" content="Technology" />
<meta property="article:tag" content="Node.js" />
```

## Twitter Card Template

```html
<!-- summary_large_image: full-width image card (recommended for most content) -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="Primary Keyword: Value Proposition" />
<meta name="twitter:description" content="Twitter-optimized description. Under 200 chars for best display." />
<meta name="twitter:image" content="https://example.com/images/og/page-name.jpg" />
<meta name="twitter:image:alt" content="Descriptive alt text" />
<meta name="twitter:site" content="@brandhandle" />
<meta name="twitter:creator" content="@authorhandle" />
```

## Schema.org JSON-LD — Article

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Primary Keyword: Full Article Title Here",
  "description": "150-160 char article description matching meta description.",
  "image": {
    "@type": "ImageObject",
    "url": "https://example.com/images/article-hero.jpg",
    "width": 1200,
    "height": 630
  },
  "datePublished": "2026-04-02T10:00:00Z",
  "dateModified": "2026-04-02T12:00:00Z",
  "author": {
    "@type": "Person",
    "name": "Author Name",
    "url": "https://example.com/author/author-name"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Brand Name",
    "logo": {
      "@type": "ImageObject",
      "url": "https://example.com/logo.png",
      "width": 600,
      "height": 60
    }
  },
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://example.com/blog/article-slug"
  }
}
</script>
```

## Schema.org JSON-LD — Product

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Product Name",
  "description": "Detailed product description.",
  "image": ["https://example.com/images/product-1.jpg"],
  "sku": "PROD-001",
  "brand": {
    "@type": "Brand",
    "name": "Brand Name"
  },
  "offers": {
    "@type": "Offer",
    "url": "https://example.com/products/product-slug",
    "priceCurrency": "USD",
    "price": "29.99",
    "availability": "https://schema.org/InStock",
    "priceValidUntil": "2026-12-31"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.5",
    "reviewCount": "127"
  }
}
</script>
```

## Schema.org JSON-LD — BreadcrumbList

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {
      "@type": "ListItem",
      "position": 1,
      "name": "Home",
      "item": "https://example.com"
    },
    {
      "@type": "ListItem",
      "position": 2,
      "name": "Blog",
      "item": "https://example.com/blog"
    },
    {
      "@type": "ListItem",
      "position": 3,
      "name": "Article Title",
      "item": "https://example.com/blog/article-slug"
    }
  ]
}
</script>
```

## Next.js 14 Metadata API

```ts
// app/blog/[slug]/page.tsx
import { Metadata } from 'next';

interface Props { params: { slug: string }; }

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const post = await getPostBySlug(params.slug); // your data fetch

  return {
    title: `${post.title} | Blog`,
    description: post.excerpt,
    alternates: {
      canonical: `https://example.com/blog/${params.slug}`,
    },
    openGraph: {
      type: 'article',
      title: post.title,
      description: post.excerpt,
      url: `https://example.com/blog/${params.slug}`,
      publishedTime: post.publishedAt.toISOString(),
      modifiedTime: post.updatedAt.toISOString(),
      authors: [post.author.profileUrl],
      images: [
        {
          url: post.ogImage ?? 'https://example.com/og-default.jpg',
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      images: [post.ogImage ?? 'https://example.com/og-default.jpg'],
    },
  };
}

// app/layout.tsx — global defaults (will be merged/overridden per page)
export const metadata: Metadata = {
  metadataBase: new URL('https://example.com'),
  title: { template: '%s | Brand Name', default: 'Brand Name — Tagline' },
  description: 'Default site description (150-160 chars).',
  openGraph: { siteName: 'Brand Name', locale: 'en_US', type: 'website' },
  twitter: { card: 'summary_large_image', site: '@brandhandle' },
  robots: { index: true, follow: true },
};
```

## Content Brief Format

```
# Content Brief: [Target Keyword]

## Page Goal
[One sentence: what action should users take after reading?]

## Target Audience
[Who is this for? What do they already know? What do they want to accomplish?]

## Keyword Strategy
- Primary keyword: [keyword] — target density: 1-2% (1-2 uses per 100 words)
- Secondary keywords: [kw1], [kw2], [kw3] — use naturally, 1-3 times each
- LSI keywords: [semantic variants] — include to signal topical depth
- Avoid: [over-optimized phrases to stay away from]

## Structure
- H1: [Must include primary keyword. Compelling. Under 60 chars.]
- H2: [Section 1 — addresses main user question]
- H2: [Section 2 — supporting evidence or how-to steps]
- H2: [Section 3 — use case or example]
- H2: [Section 4 — FAQ or comparison]
- H2: [Conclusion + CTA]

## Content Requirements
- Word count: 1,200–1,800 words (long enough for depth, short enough for focus)
- Reading level: Grade 8-10 (use Hemingway App to check)
- Include: at least 1 original image or diagram, 2-3 internal links, 1-2 external authority links

## Internal Linking Rules
- Link to at least 2 related pages on the same site
- Anchor text must be descriptive (no "click here" or "read more")
- Link to higher-authority pages (pillar content) when relevant
- Do not link to the same page twice in one article
```

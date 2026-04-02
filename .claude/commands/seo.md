Generate complete SEO meta tags, Open Graph tags, Twitter Card, and Schema.org JSON-LD for the given URL or content.

@.claude/skills/seo-content.md
@.claude/skills/frontend.md

$ARGUMENTS

The argument is either a URL to analyze or a content description. Generate the following:

1. **Page Analysis** — Brief assessment of:
   - Page type (article, product, landing page, category, etc.)
   - Primary keyword identified or inferred
   - Target audience

2. **HTML Meta Tags** — Complete head section tags:
   ```html
   <title>Primary Keyword — Brand Name | Category</title>
   <meta name="description" content="150-160 char description with primary keyword in first 20 words." />
   <meta name="robots" content="index, follow" />
   <link rel="canonical" href="https://example.com/exact-url" />
   ```

3. **Open Graph Tags**:
   ```html
   <meta property="og:type" content="website|article|product" />
   <meta property="og:title" content="Same as title tag or optimized variant" />
   <meta property="og:description" content="Same as meta description or social-optimized variant" />
   <meta property="og:url" content="https://example.com/exact-url" />
   <meta property="og:image" content="https://example.com/og-image.jpg" />
   <meta property="og:image:width" content="1200" />
   <meta property="og:image:height" content="630" />
   <meta property="og:site_name" content="Brand Name" />
   ```

4. **Twitter Card Tags**:
   ```html
   <meta name="twitter:card" content="summary_large_image" />
   <meta name="twitter:title" content="..." />
   <meta name="twitter:description" content="..." />
   <meta name="twitter:image" content="..." />
   <meta name="twitter:site" content="@handle" />
   ```

5. **Schema.org JSON-LD** — Choose the most appropriate schema type and output complete JSON-LD:
   - Article: for blog posts
   - Product: for product pages
   - BreadcrumbList: always include if page has hierarchy
   - Organization: for homepage
   ```html
   <script type="application/ld+json">
   { ... complete schema ... }
   </script>
   ```

6. **Next.js Metadata API** — The equivalent using Next.js 14 `generateMetadata`:
   ```ts
   import { Metadata } from 'next';

   export const metadata: Metadata = {
     title: '...',
     description: '...',
     openGraph: { ... },
     twitter: { ... },
   };
   ```

7. **Content Brief** — If the input is a content description (not a URL):
   - Suggested H1 (with primary keyword)
   - Suggested H2 sections (3-5)
   - Word count target
   - Primary keyword: target density 1-2%
   - LSI keywords to include naturally

Rules:
- Title must be 50-60 characters.
- Description must be 150-160 characters.
- OG image must be specified as 1200x630px.
- Never keyword-stuff — descriptions must read naturally.
- Canonical URL must be the exact canonical form (trailing slash consistent, lowercase).
- All URLs in output must use `https://`.

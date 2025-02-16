# staticseek Example (Nuxt)

Experience this implementation in action at [staticseek-nuxt.pages.dev](https://staticseek-nuxt.pages.dev/).

## Getting Started

To launch the development server locally, execute these commands:

```bash
npm install
npm run dev
```

Navigate to [http://localhost:3000](http://localhost:3000) in your browser to view the application.

## Deployment

This example is optimized for static hosting platforms. To generate and deploy the static files:

```bash
npm install
npm run generate
# Deploy the generated ".output/public" directory to your HTTP server
```

## Integration Guide: StaticSeek with Nuxt

### 0. Creating the Post Index Page

Nuxt generates static HTML files by traversing links from the root (`/`) page. Therefore, all posts must be accessible from the root. In this implementation, the `/posts` page serves as an index containing links to all individual posts.

### 1. Creating the Search Index

Begin by creating a static index file. Here's how to implement this at `server/routes/searchindex.json.ts`:

```typescript
import { HybridTrieBigramInvertedIndex, StaticSeekError, createIndex, indexToObject } from "staticseek";
import type { IndexClass } from "staticseek";
import matter from "gray-matter";

export default defineEventHandler(async (event) => {
    const raw_posts = await queryCollection(event, "posts").all();
    const posts = raw_posts.map((post) => ({ path: post.path, body: matter(post.rawbody.replaceAll("\\n", "\n")) }));

    const index_class: IndexClass = HybridTrieBigramInvertedIndex;
    const index = createIndex(index_class, posts, { 
        key_fields: ["path", "body.data.title"], 
        search_targets: ["body.data.title", "body.content"] 
    });
    
    if (index instanceof StaticSeekError) {
        throw createError({
            statusCode: 500,
            message: index.message
        });
    }
    
    return indexToObject(index);
});
```

To use `rawbody` of the posts, configure schema in `content.config.ts`:

```typescript
import { defineContentConfig, defineCollection, z } from "@nuxt/content";

export default defineContentConfig({
  collections: {
    posts: defineCollection({
        type: 'page',
        source: 'posts/*.md',
        schema: z.object({
          title: z.string(),
          rawbody: z.string(),
        }),
      }),
    }
  },
);
```

To generate `searchindex.json` staticaly, configure `nitro` in `nuxt.config.ts`:

```typescript
// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: ['@nuxt/content'],
  compatibilityDate: '2024-11-01',
  devtools: { enabled: true },
  nitro: {
    prerender: {
      crawlLinks: true,
      routes: ["/searchindex.json"],
    },
  },
})
```

Essential configuration points:
- Utilize `GPULinearIndex` for search functionality (alternative index types are available)
- Retrieve posts using Nuxt Content's `queryCollection` function
- Define collection directory and schema in `content.config.ts`
- Specify `key_fields` to determine which fields are available in search results (path and title in this example)
- Configure `search_targets` to define searchable fields (content and title in this example)
- Convert the index to JSON using `indexToObject` before serving

### 2. Implementing the Search Interface

Create a search interface page (e.g., in `pages/index.vue`) using the [StaticSeek component](https://github.com/osawa-naotaka/staticseek-vue):

```vue
<script setup lang="ts">
import StaticSeek from "../component/StaticSeek.vue";

// ad-hock solution. you might as well use zod or something like that to validate the key.
function typedKey(key: Record<string, unknown>) {
    return key as { path: string; body: { data: { title: string } } };
}

const query = ref("");
const trigger = ref(false);
</script>

<template>
    <section>
        <div class="input-area">
            <div>search</div>
            <input type="text" name="search" id="search" v-model="query" @input="() => { trigger = true }"/>
        </div>
        <StaticSeek v-if="trigger" :query="query" url="/searchindex.json">
            <template #default="{ results }">
                <h2>results</h2>
                <ul class="search-results">
                    <li v-if="results.length === 0 && query.length !== 0">No results found.</li>
                    <template v-else>
                        <li v-for="{refs, key} in results" :key="typedKey(key).path">
                            <NuxtLink :to="typedKey(key).path" >
                                <h3>{{ typedKey(key).body.data.title }}</h3>
                            </NuxtLink>
                            <p>{{ refs[0].wordaround }}</p>
                        </li>
                    </template>
                </ul>
            </template>
            <template #suspence><div>loading index...</div></template>
        </StaticSeek>
    </section>
</template>
```

The StaticSeek component manages index loading and search execution efficiently:
- Implements lazy loading via the `trigger` ref to prevent loading the search index until user interaction
- Passes the `query` v-model from the input element to StaticSeek for search operations
- Uses the `url` prop to reference the pre-generated search index JSON file
- Provides a `suspense` slot for loading state visualization
- Includes a `default` slot that transforms `SearchResult[]` into HTML elements via `#default="{ results }"`

Key features:
- Results are automatically sorted by relevance score
- Each result entry contains:
  - Key fields specified during index creation (`title` and `path`)
  - Contextual content matches via `refs[*].wordaround`
  - Direct links to full posts using the `path` property

### 3. Index Loading and Search Implementation

The `StaticSeek` Vue component, available through [staticseek-vue](https://github.com/osawa-naotaka/staticseek-vue), handles index loading and search execution. Here's the complete implementation:

```vue
<script setup lang="tsx">
import type { SearchResult, StaticSeekIndex } from "staticseek";
import { StaticSeekError, createIndexFromObject, search } from "staticseek";

interface Props {
    query: string,
    url: string,
}
const { query, url } = defineProps<Props>();

const index = ref<StaticSeekIndex>();
const loading = ref(true);
const results = ref<SearchResult[]>([]);

async function init() {
    const { data } = await useFetch<StaticSeekIndex>(url);
    if (!data.value) {
        throw new Error("Failed to fetch search index.");
    }
    const newIndex = createIndexFromObject(data.value);

    if (newIndex instanceof StaticSeekError) {
        throw newIndex;
    }

    index.value = newIndex;
    loading.value = false;
}

watch(() => query, async (q) => {
    if (!index.value) {
        results.value = [];
        return ;
    }
    const searchResults = await search(index.value, q);
    if (searchResults instanceof StaticSeekError) {
        console.error(searchResults);
        results.value = [];
        return;
    }

    results.value = searchResults;
});

init();
</script>

<template>
    <template v-if="loading">
        <slot name="suspence"></slot>
    </template>
    <template v-else>
        <slot name="default" :results="results"></slot>
    </template>
</template>
```

Implementation highlights:
- Loads the search index once during component initialization via asynchronous `init()`
- Implements reactive search using a watch dependency on `() => query`
- Passes search results to the render template through the `results` prop
- Provides comprehensive error handling for both index creation and search operations

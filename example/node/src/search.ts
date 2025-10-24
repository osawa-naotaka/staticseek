import { readFileSync } from "node:fs";
import { createIndexFromObject, StaticSeekError, search } from "staticseek";
import * as v from "valibot";

if(process.argv.length < 4) {
    console.error("Usage: tsx src/search.ts <indexFilePath> <query>");
    process.exit(1);
}

const indexFilePath = process.argv[2];
const query = process.argv[3];

const indexData = readFileSync(indexFilePath, "utf-8");
const indexObject = JSON.parse(indexData);

const index = createIndexFromObject(indexObject);
if(index instanceof StaticSeekError) {
    console.error("Error loading index:", index.message);
    process.exit(1);
}

const result = await search(index, query);
if(result instanceof StaticSeekError) {
    console.error("Error during search:", result.message);
    process.exit(1);
}

console.log("Search results for query:", query);
if(result.length === 0) {
    console.log("No results found.");
} else {
    const schema = v.object({
        slug: v.string(),
        data: v.object({
            title: v.string(),
        }),
    });
    result.forEach((item, idx) => {
        const key = v.parse(schema, item.key);
        console.log(`${idx + 1}. title: ${key.data.title}, slug: ${key.slug}, from "${item.refs[0].wordaround}"`);
    });
}

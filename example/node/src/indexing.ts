import { LinearIndex, StaticSeekError, createIndex, indexToObject } from "staticseek";
import { readFileSync, writeFileSync } from "node:fs";

if (process.argv.length === 4) {
    const inputFilePath = process.argv[2];
    const outputFilePath = process.argv[3];

    const fileContent = readFileSync(inputFilePath, "utf-8");
    const docs = JSON.parse(fileContent);

    const index = createIndex(LinearIndex, docs, { key_fields: ["data.title", "slug"], search_targets: ["data.title", "content"] });
    if (index instanceof StaticSeekError) {
        console.error("Error creating index:", index.message);
        process.exit(1);
    }

    const indexObject = indexToObject(index);
    writeFileSync(outputFilePath, JSON.stringify(indexObject), "utf-8");
    console.log(`Index written to ${outputFilePath}`);
    process.exit(0);
}
console.error("Usage: tsx src/indexing.ts <inputFilePath> <outputFilePath>");
process.exit(1);

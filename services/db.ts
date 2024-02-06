import { CosmosClient } from "@azure/cosmos";

const key = process.env.COSMOSDB_PRIMARY_KEY;
const endpoint = process.env.COSMOSDB_ENDPOINT;
const databaseName = process.env.COSMOSDB_NAME;
const stocksContainerName = process.env.COSMOSDB_STOCKS_CONTAINER_NAME;
const productsContainerName = process.env.COSMOSDB_PRODUCTS_CONTAINER_NAME;

const cosmosClient = new CosmosClient({ endpoint: endpoint, key: key });

const database = cosmosClient.database(databaseName);
export const productContainer = database.container(productsContainerName);
export const stockContainer = database.container(stocksContainerName);
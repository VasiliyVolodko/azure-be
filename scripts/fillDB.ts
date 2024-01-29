import { CosmosClient } from "@azure/cosmos";
import products from '../mocks/product.json';
import stocks from '../mocks/stock.json';

const key = '097teUYvNu3K0fRPZdIWZKW7137kyiH3Ax3c7z94xr2Y6wKOwrDlTWIhHo5oNRfz7YD1QJvvl6iGACDbYj6dkQ==';
const endpoint = 'https://cosmos-test-app-volodko.documents.azure.com:443/';

const databaseName = `products-db`;
const stocksContainerName = `stocks`;
const productsContainerName = `products`;


const cosmosClient = new CosmosClient({ endpoint, key });

const database = cosmosClient.database(databaseName);
const productContainer = database.container(productsContainerName);
const stockContainer = database.container(stocksContainerName);

async function fillDB() {

  for (const product of products) {
    await productContainer.items.upsert(product);
  }

  for (const stock of stocks) {
    await stockContainer.items.upsert(stock);
  }
}

fillDB()
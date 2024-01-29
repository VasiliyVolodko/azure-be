import { productContainer } from "../db/containers";
import { stockContainer } from "../db/containers";

interface IProduct {
  title: string,
  description: string,
  price: number,
  id: string
}

interface IStock {
  productId: string,
  count: number
}

export class StockService {
  static async getAll(): Promise<IStock[]> {
    const { resources: stocks } = await stockContainer.items.readAll<IStock>().fetchAll();

    return stocks.map((stock) => ({
      productId: stock.productId,
      count: stock.count
    }))
  }

  static async getById(productId: string): Promise<IStock> {
    const { resources: stock } = await stockContainer.items.query<IStock>(`SELECT * FROM c WHERE c.productId = "${productId}"`).fetchAll()
    return {
      productId: stock[0].productId,
      count: stock[0].count
    }
  }

  static async createStock(id: string): Promise<void> {
    const res = await stockContainer.items.upsert({
      productId: id,
      count: 0
    });
    console.log(res)
  }
}
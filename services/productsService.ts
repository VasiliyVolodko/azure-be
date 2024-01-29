import { productContainer } from "../db/containers";
import { StockService } from "./stocksService";

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

export class ProductService {
  static async getAll(): Promise<(IProduct & Omit<IStock, 'productId'>)[]> {
    const { resources: products } = await productContainer.items.readAll<IProduct>().fetchAll();
    const stocks = await StockService.getAll();

    return products.map((product) => {
      const stock = stocks.find((stock) => stock.productId === product.id)

      return {
        title: product.title,
        description: product.description,
        id: product.id,
        price: product.price,
        count: stock?.count || 0
      }
    })
  }

  static async getById(id: string): Promise<IProduct & Omit<IStock, 'productId'>> {
    const { resource: product } = await productContainer.item(id, id).read();
    const stock = await StockService.getById(id);

    return {
      title: product.title,
      description: product.description,
      id: product.id,
      price: product.price,
      count: stock?.count || 0
    }
  }

  static async createProduct(product: IProduct): Promise<void> {
    const { item: { id } } = await productContainer.items.upsert(product);
    await StockService.createStock(id)
  }
}
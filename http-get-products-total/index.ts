import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ProductService } from "../services/productsService";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log(`HTTP trigger function processed a request. request: ${req}`);

    const products = await ProductService.getAll()
    context.res = {
        body: {
            tatalProducts: products.length
        }
    };

};

export default httpTrigger;
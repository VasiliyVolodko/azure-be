import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ProductService } from "../services/productsService";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log(`HTTP trigger function processed a request. request: ${req}`);

    const { params: { productId } } = req
    const productResponse = await ProductService.getById(productId)

    if (productResponse) {
        context.res = {
            body: productResponse
        };
    } else {
        context.res = {
            status: 404,
            body: "Product not found"
        };
    }
    

};

export default httpTrigger;
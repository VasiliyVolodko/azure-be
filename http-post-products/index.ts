import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ProductService } from "../services/productsService";
import { productPutSchema } from "../schemas/product.schema";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log(`HTTP trigger function processed a request. request: ${req}`);

    const validation = productPutSchema.safeParse(req.body)

    if (validation.success) {
        await ProductService.createProduct(req.body)

        context.res = {
            body: 'ok'
        };
    } else {
        context.res = {
            status: 400,
            body: 'incorrect data'
        };
    }
};

export default httpTrigger;
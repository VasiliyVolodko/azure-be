import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ProductService } from "../services/productsService";
import { z } from "zod"

const productSchema = z.object({
    title: z.string(),
    description: z.string(),
    price: z.number()
})
const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log(`HTTP trigger function processed a request. request: ${req}`);

    const validation = productSchema.safeParse(req.body)

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
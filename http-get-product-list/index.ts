import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { ProductService } from "../services/productsService";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log(`HTTP trigger function processed a request. request: ${req}`);
    context.res = {
        body: await ProductService.getAll()
    };

};

export default httpTrigger;
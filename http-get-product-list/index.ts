import { AzureFunction, Context, HttpRequest } from "@azure/functions"
import { PRODUCT_LIST } from "../mocks/product_list";

const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest): Promise<void> {
    context.log('HTTP trigger function processed a request.');
    context.res = {
        // status: 200, /* Defaults to 200 */
        body: PRODUCT_LIST
    };

};

export default httpTrigger;
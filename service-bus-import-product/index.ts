import { AzureFunction, Context } from "@azure/functions"
import { ProductService } from "../services/productsService";
import { importSchema } from "../schemas/product.schema";

const serviceBusQueueTrigger: AzureFunction = async function(context: Context, msg: any): Promise<void> {
    context.log('ServiceBus queue trigger function processed message', msg);
    try {
        const product = JSON.parse(msg)

        const validation = importSchema.safeParse(product)

        if (validation.success) {
            await ProductService.createProduct(product)
        } else {
            context.log(`some error happened on ${msg}`)
        }
    } catch (e) {
        context.log(e)
    }


};

export default serviceBusQueueTrigger;

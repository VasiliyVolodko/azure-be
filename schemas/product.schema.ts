import { z } from "zod"

export const productPutSchema = z.object({
  title: z.string(),
  description: z.string(),
  price: z.number(),
  count: z.number()
})

export const importSchema = z.object({
  title: z.string(),
  description: z.string(),
  price: z.string(),
  count: z.string().optional()
})
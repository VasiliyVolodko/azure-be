# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "product_service_rg" {
  location = "northeurope"
  name     = "rg-product-service-sand-ne-001"
}

resource "azurerm_storage_account" "products_service_fa" {
  name     = "stgaccountproductservice"
  location = "northeurope"

  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"

  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_storage_share" "products_service_fa" {
  name  = "fa-products-service-share"
  quota = 2

  storage_account_name = azurerm_storage_account.products_service_fa.name
}

resource "azurerm_service_plan" "product_service_plan" {
  name     = "asp-product-service-sand-ne-001"
  location = "northeurope"

  os_type  = "Windows"
  sku_name = "Y1"

  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_application_insights" "products_service_fa" {
  name             = "appins-fa-products-service-sand-ne-001"
  application_type = "web"
  location         = "northeurope"


  resource_group_name = azurerm_resource_group.product_service_rg.name
}


resource "azurerm_windows_function_app" "products_service" {
  name     = "func-app-product-service"
  location = "northeurope"

  service_plan_id     = azurerm_service_plan.product_service_plan.id
  resource_group_name = azurerm_resource_group.product_service_rg.name

  storage_account_name       = azurerm_storage_account.products_service_fa.name
  storage_account_access_key = azurerm_storage_account.products_service_fa.primary_access_key

  functions_extension_version = "~4"
  builtin_logging_enabled     = false

  site_config {
    always_on = false

    application_insights_key               = azurerm_application_insights.products_service_fa.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.products_service_fa.connection_string

    # For production systems set this to false
    use_32_bit_worker = false

    # Enable function invocations from Azure Portal.
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }

    application_stack {
      node_version = "~16"
    }
  }

  app_settings = {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.products_service_fa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.products_service_fa.name
  }

  # The app settings changes cause downtime on the Function App. e.g. with Azure Function App Slots
  # Therefore it is better to ignore those changes and manage app settings separately off the Terraform.
  lifecycle {
    ignore_changes = [
      app_settings,
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"]
    ]
  }
}

resource "azurerm_resource_group" "apim" {
  name     = "rg-apim-sand-ne-vv"
  location = "northeurope"
}


resource "azurerm_api_management" "core_apim" {
  location        = "northeurope"
  name            = "apim-product-service-vv"
  publisher_email = "volodkovasya@gmail.com"
  publisher_name  = "Volodko Vasiliy"

  resource_group_name = azurerm_resource_group.apim.name
  sku_name            = "Consumption_0"
}

resource "azurerm_api_management_api" "products_api" {
  name                = "products-service-api"
  resource_group_name = azurerm_resource_group.apim.name
  api_management_name = azurerm_api_management.core_apim.name
  revision            = "1"
  path                = "func-app-product-service"

  display_name = "Products Service API"

  protocols             = ["https"]
  subscription_required = false
}

data "azurerm_function_app_host_keys" "products_keys" {
  name                = azurerm_windows_function_app.products_service.name
  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_api_management_backend" "products_fa" {
  name                = "products-service-backend-vv"
  resource_group_name = azurerm_resource_group.apim.name
  api_management_name = azurerm_api_management.core_apim.name
  protocol            = "http"
  url                 = "https://${azurerm_windows_function_app.products_service.name}.azurewebsites.net/api"
  description         = "Products API"

  credentials {
    certificate = []
    query       = {}

    header = {
      "x-functions-key" = data.azurerm_function_app_host_keys.products_keys.default_function_key
    }
  }
}

resource "azurerm_api_management_api_policy" "api_policy" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.products_api.name
  api_management_name = azurerm_api_management.core_apim.name

  xml_content = <<XML
 <policies>
 	<inbound>
 		<set-backend-service backend-id="${azurerm_api_management_backend.products_fa.name}"/>
 		<base/>    
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
      </allowed-methods>
    </cors>
 	</inbound>
 	<backend>
 		<base/>
 	</backend>
 	<outbound>
 		<base/>
 	</outbound>
 	<on-error>
 		<base/>
 	</on-error>
 </policies>
XML
}

resource "azurerm_api_management_api_operation" "get_products" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.products_api.name
  api_management_name = azurerm_api_management.core_apim.name
  display_name        = "Get Products"
  method              = "GET"
  operation_id        = "http-get-product-list"
  url_template        = "/products"
}

resource "azurerm_api_management_api_operation" "get_product_by_id" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.products_api.name
  api_management_name = azurerm_api_management.core_apim.name
  display_name        = "Get Product by ID"
  method              = "GET"
  operation_id        = "http-get-product-by-id"
  url_template        = "/products/{productId}"

  template_parameter {
    name     = "productId"
    required = true
    type     = "string"
  }
}

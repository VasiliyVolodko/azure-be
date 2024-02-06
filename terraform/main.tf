# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.89.0"
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
    AzureWebJobsMyServiceBus                 = azurerm_servicebus_namespace_authorization_rule.service-rule-vldk.primary_connection_string
    SERVICE_BUS_CONNECTION_STRING            = azurerm_servicebus_namespace_authorization_rule.service-rule-vldk.primary_connection_string
    COSMOSDB_PRIMARY_KEY                     = azurerm_cosmosdb_account.test_app.primary_key
    COSMOSDB_ENDPOINT                        = azurerm_cosmosdb_account.test_app.endpoint
    COSMOSDB_NAME                            = azurerm_cosmosdb_sql_database.products_app.name
    COSMOSDB_PRODUCTS_CONTAINER_NAME         = azurerm_cosmosdb_sql_container.products.name
    COSMOSDB_STOCKS_CONTAINER_NAME           = azurerm_cosmosdb_sql_container.stocks.name
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
  name                = "products-service-backend-volodko-003"
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
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods preflight-result-max-age="300">
        <method>*</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
      <expose-headers>
        <header>*</header>
      </expose-headers>
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

resource "azurerm_api_management_api_operation" "get_products_total" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.products_api.name
  api_management_name = azurerm_api_management.core_apim.name
  display_name        = "Get Products Total"
  method              = "GET"
  operation_id        = "http-get-product-total"
  url_template        = "/products/total"
}

resource "azurerm_api_management_api_operation" "post_product" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.products_api.name
  api_management_name = azurerm_api_management.core_apim.name
  display_name        = "Post Product"
  method              = "PUT"
  operation_id        = "http-post-product"
  url_template        = "/products"
}

resource "azurerm_cosmosdb_account" "test_app" {
  location            = "northeurope"
  name                = "cosmos-test-app-volodko"
  offer_type          = "Standard"
  resource_group_name = azurerm_resource_group.product_service_rg.name
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Eventual"
  }

  capabilities {
    name = "EnableServerless"
  }

  geo_location {
    failover_priority = 0
    location          = "North Europe"
  }
}

resource "azurerm_cosmosdb_sql_database" "products_app" {
  account_name        = azurerm_cosmosdb_account.test_app.name
  name                = "products-db"
  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_cosmosdb_sql_container" "products" {
  account_name        = azurerm_cosmosdb_account.test_app.name
  database_name       = azurerm_cosmosdb_sql_database.products_app.name
  name                = "products"
  partition_key_path  = "/id"
  resource_group_name = azurerm_resource_group.product_service_rg.name

  # Cosmos DB supports TTL for the records
  default_ttl = -1

  indexing_policy {
    excluded_path {
      path = "/*"
    }
  }
}

resource "azurerm_cosmosdb_sql_container" "stocks" {
  account_name        = azurerm_cosmosdb_account.test_app.name
  resource_group_name = azurerm_resource_group.product_service_rg.name
  database_name       = azurerm_cosmosdb_sql_database.products_app.name
  name                = "stocks"
  partition_key_path  = "/product_id"

  # Cosmos DB supports TTL for the records
  default_ttl = -1

  indexing_policy {
    included_path {
      path = "/product_id/?"
    }

    excluded_path {
      path = "/*"
    }
  }
}

resource "azurerm_resource_group" "import_service_rg" {
  name     = "rg-import-service-sand-ne-vol"
  location = "northeurope"
}

resource "azurerm_storage_account" "import_service_files" {
  name     = "volodkoimportfiles001"
  location = "northeurope"

  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["PUT", "GET"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 0
    }
  }

  resource_group_name = azurerm_resource_group.import_service_rg.name
}


resource "azurerm_storage_container" "uploaded_container" {
  name                  = "uploaded"
  storage_account_name  = azurerm_storage_account.import_service_files.name
  container_access_type = "blob"
}

resource "azurerm_storage_container" "parsed_container" {
  name                  = "parsed"
  storage_account_name  = azurerm_storage_account.import_service_files.name
  container_access_type = "blob"
}

resource "azurerm_storage_share" "import_service_fa" {
  name  = "fa-import-service-dev-voldk-share"
  quota = 2

  storage_account_name = azurerm_storage_account.import_service_files.name
}

resource "azurerm_service_plan" "import_service_plan" {
  name                = "asp-import-service-sand-ne-py-vol"
  resource_group_name = azurerm_resource_group.import_service_rg.name
  location            = azurerm_resource_group.import_service_rg.location

  os_type  = "Windows"
  sku_name = "Y1"
}

resource "azurerm_application_insights" "import_service_fa" {
  name                = "appins-fa-import-service-sand-ne-vol"
  resource_group_name = azurerm_resource_group.import_service_rg.name
  location            = azurerm_resource_group.import_service_rg.location
  application_type    = "web"
}

resource "azurerm_windows_function_app" "import_service" {
  name                = "fa-import-service-ne-vol"
  resource_group_name = azurerm_resource_group.import_service_rg.name
  location            = azurerm_resource_group.import_service_rg.location

  service_plan_id = azurerm_service_plan.import_service_plan.id

  storage_account_name       = azurerm_storage_account.import_service_files.name
  storage_account_access_key = azurerm_storage_account.import_service_files.primary_access_key

  functions_extension_version = "~4"
  builtin_logging_enabled     = false

  site_config {
    always_on = false

    application_insights_key               = azurerm_application_insights.import_service_fa.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.import_service_fa.connection_string

    # For production systems set this to false
    use_32_bit_worker = true

    # Enable function invocations from Azure Portal.
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }

    application_stack {
      node_version = "~16"
    }
  }

  app_settings = {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.import_service_files.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.import_service_fa.name
    STORAGE_UPLOAD_CONTAINER                 = azurerm_storage_container.uploaded_container.name
    STORAGE_PARSED_CONTAINER                 = azurerm_storage_container.parsed_container.name
    SERVICE_BUS_CONNECTION_STRING            = azurerm_servicebus_namespace_authorization_rule.service-rule-vldk.primary_connection_string
    QUEUE_NAME                               = azurerm_servicebus_queue.service_bus_queue_vldk.name
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

resource "azurerm_api_management_api" "import_api" {
  name                = "import-service-api-vol"
  resource_group_name = azurerm_resource_group.apim.name
  api_management_name = azurerm_api_management.core_apim.name
  revision            = "1"
  path                = "import-service"

  display_name = "Import Service API"

  protocols             = ["https"]
  subscription_required = false
}

data "azurerm_function_app_host_keys" "import_keys" {
  name                = azurerm_windows_function_app.import_service.name
  resource_group_name = azurerm_resource_group.import_service_rg.name
}

resource "azurerm_api_management_backend" "import_fa" {
  name                = "import-service-backend-vol"
  resource_group_name = azurerm_resource_group.apim.name
  api_management_name = azurerm_api_management.core_apim.name
  protocol            = "http"
  url                 = "https://${azurerm_windows_function_app.import_service.name}.azurewebsites.net/api"
  description         = "Import API"

  credentials {
    certificate = []
    query       = {}

    header = {
      "x-functions-key" = data.azurerm_function_app_host_keys.import_keys.default_function_key
    }
  }
}

resource "azurerm_api_management_api_policy" "import_api_policy" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.import_api.name
  api_management_name = azurerm_api_management.core_apim.name

  xml_content = <<XML
 <policies>
 	<inbound>
 		<set-backend-service backend-id="${azurerm_api_management_backend.import_fa.name}"/>
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods preflight-result-max-age="300">
        <method>*</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
      <expose-headers>
        <header>*</header>
      </expose-headers>
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

resource "azurerm_api_management_api_operation" "import_csv" {
  resource_group_name = azurerm_resource_group.apim.name
  api_name            = azurerm_api_management_api.import_api.name
  api_management_name = azurerm_api_management.core_apim.name
  display_name        = "Import CSV file"
  method              = "GET"
  operation_id        = "get-import-url"
  url_template        = "/import"
}

resource "azurerm_resource_group" "service_bus_queue_vldk" {
  name     = "service_bus_queue_vldk"
  location = "northeurope"
}

resource "azurerm_servicebus_namespace" "service_bus_vldk" {
  name                          = "servicebus-vldk"
  location                      = azurerm_resource_group.service_bus_queue_vldk.location
  resource_group_name           = azurerm_resource_group.service_bus_queue_vldk.name
  sku                           = "Basic"
  capacity                      = 0 /* standard for sku plan */
  public_network_access_enabled = true /* can be changed to false for premium */
  minimum_tls_version           = "1.2"
  zone_redundant                = false /* can be changed to true for premium */
}

resource "azurerm_servicebus_namespace_authorization_rule" "service-rule-vldk" {
  name         = "service-rule-vldk"
  namespace_id = azurerm_servicebus_namespace.service_bus_vldk.id

  listen = true
  send   = true
  manage = false
}

resource "azurerm_servicebus_queue" "service_bus_queue_vldk" {
  name                                    = "servicebus-queue-vldk"
  namespace_id                            = azurerm_servicebus_namespace.service_bus_vldk.id
  lock_duration                           = "PT1M" /* ISO 8601 timespan duration, 5 min is max */
  requires_duplicate_detection            = false
  duplicate_detection_history_time_window = "PT10M" /* ISO 8601 timespan duration, 5 min is max */
  requires_session                        = false
  dead_lettering_on_message_expiration    = false
}

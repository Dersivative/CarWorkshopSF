public with sharing class WorkOrderDetailController {
    public class WorkOrderDetailDto {
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderName;
        @AuraEnabled public Id assignedEmployeeId;
        @AuraEnabled public String assignedEmployeeName;
        @AuraEnabled public Id visitId;
        @AuraEnabled public String visitName;
        @AuraEnabled public Datetime checkInAt;
        @AuraEnabled public Datetime checkOutAt;
        @AuraEnabled public Decimal odometerKm;
        @AuraEnabled public Id vehicleId;
        @AuraEnabled public String vehiclePlate;
        @AuraEnabled public String vehicleMake;
        @AuraEnabled public String vehicleModel;
        @AuraEnabled public Decimal vehicleYear;
        @AuraEnabled public List<WorkOrderLineDto> lineItems;
        @AuraEnabled public Decimal grossTotal;
    }

    public class WorkOrderLineDto {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public String lineType;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal grossLineTotal;
    }

    public class ServiceCatalogDto {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Description;
        @AuraEnabled public Decimal NetPrice;
        @AuraEnabled public Decimal TaxRate;
        @AuraEnabled public Decimal GrossPrice;
        @AuraEnabled public Decimal DefaultLabourHours;
    }

    public class ProductCatalogDto {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Description;
        @AuraEnabled public Decimal NetPrice;
        @AuraEnabled public Decimal TaxRate;
        @AuraEnabled public Decimal GrossPrice;
    }

    @AuraEnabled(cacheable=true)
    public static WorkOrderDetailDto getWorkOrderDetail(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order Id is required.');
        }

        WorkOrder__c workOrder = [
            SELECT Id,
                Name,
                Assigned_Employee__c,
                Assigned_Employee__r.Name,
                Visit__c,
                Visit__r.Name,
                Visit__r.Check_in_At__c,
                Visit__r.Check_out_At__c,
                Visit__r.Odometer_km__c,
                Visit__r.Vehicle__c,
                Visit__r.Vehicle__r.Plate__c,
                Visit__r.Vehicle__r.Make__c,
                Visit__r.Vehicle__r.Model__c,
                Visit__r.Vehicle__r.Year__c
            FROM WorkOrder__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        List<Work_Order_Line_Item__c> lineItems = [
            SELECT Id,
                Line_Type__c,
                Product__c,
                Product__r.Product_Description__c,
                Service__c,
                Service__r.Service_Description__c,
                Quantity__c,
                Unit_Price__c,
                Tax_Rate__c,
                Gross_Line_Total__c
            FROM Work_Order_Line_Item__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY CreatedDate ASC
        ];

        WorkOrderDetailDto detail = new WorkOrderDetailDto();
        detail.workOrderId = workOrder.Id;
        detail.workOrderName = workOrder.Name;
        detail.assignedEmployeeId = workOrder.Assigned_Employee__c;
        detail.assignedEmployeeName = workOrder.Assigned_Employee__r != null ? workOrder.Assigned_Employee__r.Name : null;
        detail.visitId = workOrder.Visit__c;
        detail.visitName = workOrder.Visit__r != null ? workOrder.Visit__r.Name : null;
        detail.checkInAt = workOrder.Visit__r != null ? workOrder.Visit__r.Check_in_At__c : null;
        detail.checkOutAt = workOrder.Visit__r != null ? workOrder.Visit__r.Check_out_At__c : null;
        detail.odometerKm = workOrder.Visit__r != null ? workOrder.Visit__r.Odometer_km__c : null;
        detail.vehicleId = workOrder.Visit__r != null ? workOrder.Visit__r.Vehicle__c : null;
        detail.vehiclePlate = workOrder.Visit__r != null ? workOrder.Visit__r.Vehicle__r.Plate__c : null;
        detail.vehicleMake = workOrder.Visit__r != null ? workOrder.Visit__r.Vehicle__r.Make__c : null;
        detail.vehicleModel = workOrder.Visit__r != null ? workOrder.Visit__r.Vehicle__r.Model__c : null;
        detail.vehicleYear = workOrder.Visit__r != null ? workOrder.Visit__r.Vehicle__r.Year__c : null;
        detail.lineItems = new List<WorkOrderLineDto>();
        detail.grossTotal = 0;

        for (Work_Order_Line_Item__c lineItem : lineItems) {
            WorkOrderLineDto lineDto = new WorkOrderLineDto();
            lineDto.lineItemId = lineItem.Id;
            lineDto.lineType = lineItem.Line_Type__c;
            lineDto.name = lineItem.Product__c != null
                ? lineItem.Product__r.Product_Description__c
                : lineItem.Service__r.Service_Description__c;
            lineDto.units = lineItem.Quantity__c;
            lineDto.price = lineItem.Unit_Price__c;
            lineDto.tax = lineItem.Tax_Rate__c;
            lineDto.grossLineTotal = lineItem.Gross_Line_Total__c;
            detail.lineItems.add(lineDto);

            if (lineItem.Gross_Line_Total__c != null) {
                detail.grossTotal += lineItem.Gross_Line_Total__c;
            }
        }

        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceCatalogDto> getServiceCatalog() {
        List<ServiceCatalogDto> result = new List<ServiceCatalogDto>();
        for (Service__c s : [
            SELECT Id, Name, Service_Description__c, Hourly_Rate__c, Tax_Rate__c, Default_Labour_Hours__c
            FROM Service__c
            ORDER BY Name
        ]) {
            ServiceCatalogDto dto = new ServiceCatalogDto();
            dto.Id = s.Id;
            dto.Name = s.Name;
            dto.Description = s.Service_Description__c;
            dto.NetPrice = s.Hourly_Rate__c;
            dto.TaxRate = s.Tax_Rate__c;
            dto.GrossPrice = s.Hourly_Rate__c != null && s.Tax_Rate__c != null
                ? s.Hourly_Rate__c * (1 + s.Tax_Rate__c)
                : null;
            dto.DefaultLabourHours = s.Default_Labour_Hours__c;
            result.add(dto);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductCatalogDto> getProductCatalog() {
        List<ProductCatalogDto> result = new List<ProductCatalogDto>();
        for (Product__c p : [
            SELECT Id, Name, Product_Description__c, Price__c, Tax_Rate__c
            FROM Product__c
            ORDER BY Name
        ]) {
            ProductCatalogDto dto = new ProductCatalogDto();
            dto.Id = p.Id;
            dto.Name = p.Name;
            dto.Description = p.Product_Description__c;
            dto.NetPrice = p.Price__c;
            dto.TaxRate = p.Tax_Rate__c;
            dto.GrossPrice = p.Price__c != null && p.Tax_Rate__c != null
                ? p.Price__c * (1 + p.Tax_Rate__c)
                : null;
            result.add(dto);
        }
        return result;
    }

    @AuraEnabled
    public static void addWorkOrderLineItem(
        Id workOrderId,
        String lineType,
        Id productId,
        Id serviceId,
        Decimal quantity,
        Decimal unitPrice,
        Decimal taxRate
    ) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order Id is required.');
        }
        if (String.isBlank(lineType)) {
            throw new AuraHandledException('Line type is required.');
        }
        if (quantity == null || quantity < 0) {
            throw new AuraHandledException('Quantity must be a non-negative number.');
        }
        if (unitPrice == null || unitPrice < 0) {
            throw new AuraHandledException('Unit price must be a non-negative number.');
        }
        if (taxRate == null || taxRate < 0) {
            throw new AuraHandledException('Tax rate must be a non-negative number.');
        }

        Work_Order_Line_Item__c line = new Work_Order_Line_Item__c(
            Work_Order__c = workOrderId,
            Line_Type__c = lineType,
            Quantity__c = quantity,
            Unit_Price__c = unitPrice,
            Tax_Rate__c = taxRate
        );
        if (lineType == 'Product') {
            if (productId == null) {
                throw new AuraHandledException('Product is required for a product line.');
            }
            line.Product__c = productId;
        } else if (lineType == 'Service') {
            if (serviceId == null) {
                throw new AuraHandledException('Service is required for a service line.');
            }
            line.Service__c = serviceId;
        } else {
            throw new AuraHandledException('Line type must be Product or Service.');
        }
        insert line;
    }

    @AuraEnabled
    public static void deleteWorkOrderLineItem(Id lineItemId) {
        if (lineItemId == null) {
            throw new AuraHandledException('Line item Id is required.');
        }
        Work_Order_Line_Item__c line = [
            SELECT Id
            FROM Work_Order_Line_Item__c
            WHERE Id = :lineItemId
            LIMIT 1
        ];
        delete line;
    }
}

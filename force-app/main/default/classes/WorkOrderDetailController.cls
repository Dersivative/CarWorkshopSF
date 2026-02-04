public with sharing class WorkOrderDetailController {
    public class WorkOrderDetailDto {
        @AuraEnabled public Id workOrderId;
        @AuraEnabled public String workOrderName;
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

    @AuraEnabled(cacheable=true)
    public static WorkOrderDetailDto getWorkOrderDetail(Id workOrderId) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order Id is required.');
        }

        WorkOrder__c workOrder = [
            SELECT Id,
                Name,
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
}

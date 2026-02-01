import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getWorkOrderDetail from '@salesforce/apex/WorkOrderDetailController.getWorkOrderDetail';

const ROW_ACTIONS = [{ label: 'Edit', name: 'edit' }];

const COLUMNS = [
    { label: 'Line Type', fieldName: 'lineType' },
    { label: 'Name', fieldName: 'name' },
    { label: 'Units', fieldName: 'units', type: 'number' },
    { label: 'Price', fieldName: 'price', type: 'currency' },
    { label: 'Tax', fieldName: 'tax', type: 'percent' },
    { label: 'Gross Line Total', fieldName: 'grossLineTotal', type: 'currency' },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

export default class WorkOrderDetail extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    @api workOrderId;
    pageWorkOrderId;
    detail;
    error;

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        const workOrderId = pageRef?.state?.c__workOrderId;
        if (workOrderId) {
            this.pageWorkOrderId = workOrderId;
        }
    }

    @wire(getWorkOrderDetail, { workOrderId: '$effectiveWorkOrderId' })
    wiredDetail({ data, error }) {
        if (data) {
            this.detail = data;
            this.error = undefined;
        } else if (error) {
            this.detail = undefined;
            this.error = error;
        }
    }

    get hasWorkOrder() {
        return Boolean(this.effectiveWorkOrderId);
    }

    get hasError() {
        return Boolean(this.error);
    }

    get lineItems() {
        return this.detail?.lineItems ?? [];
    }

    get grossTotal() {
        return this.detail?.grossTotal ?? 0;
    }

    get effectiveWorkOrderId() {
        return this.workOrderId || this.pageWorkOrderId;
    }

    get errorMessage() {
        return this.getErrorMessage(this.error);
    }

    handleAddLine() {
        const defaultValues = encodeDefaultFieldValues({
            Work_Order__c: this.effectiveWorkOrderId
        });

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Work_Order_Line_Item__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: defaultValues
            }
        });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName !== 'edit') {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: row.lineItemId,
                objectApiName: 'Work_Order_Line_Item__c',
                actionName: 'edit'
            }
        });
    }

    getErrorMessage(error) {
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }
}
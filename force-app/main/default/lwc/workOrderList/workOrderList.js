import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getWorkOrders from '@salesforce/apex/WorkOrderInvoiceController.getWorkOrders';
import createInvoiceForWorkOrder from '@salesforce/apex/WorkOrderInvoiceController.createInvoiceForWorkOrder';

const ROW_ACTIONS = [
    { label: 'View Details', name: 'view_details' },
    { label: 'Create Invoice', name: 'create_invoice' }
];

const COLUMNS = [
    {
        label: 'Work Order',
        fieldName: 'workOrderUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
    },
    {
        label: 'Visit',
        fieldName: 'visitUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'visitName' }, target: '_blank' }
    },
    {
        label: 'Created',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
    },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

export default class WorkOrderList extends LightningElement {
    columns = COLUMNS;
    workOrders = [];
    error;
    isLoading = false;
    wiredResult;

    @wire(getWorkOrders)
    wiredWorkOrders(result) {
        this.wiredResult = result;
        const { data, error } = result;

        if (data) {
            this.error = undefined;
            this.workOrders = data.map((workOrder) => ({
                ...workOrder,
                workOrderUrl: '/' + workOrder.Id,
                visitUrl: workOrder.Visit__c ? '/' + workOrder.Visit__c : null,
                visitName: workOrder.Visit__r?.Name ?? '—'
            }));
        } else if (error) {
            this.workOrders = [];
            this.error = error;
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_details') {
            this.dispatchEvent(
                new CustomEvent('workorderselect', {
                    detail: { workOrderId: row.Id },
                    bubbles: true,
                    composed: true
                })
            );
            return;
        }

        if (actionName === 'create_invoice') {
            this.isLoading = true;
            try {
                const invoiceId = await createInvoiceForWorkOrder({ workOrderId: row.Id });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invoice created',
                        message: `Invoice ${invoiceId} created from Work Order ${row.Name}.`,
                        variant: 'success'
                    })
                );
                await refreshApex(this.wiredResult);
            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Conversion failed',
                        message: this.getErrorMessage(error),
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoading = false;
            }
        }
    }

    get hasError() {
        return Boolean(this.error);
    }

    get errorMessage() {
        return this.getErrorMessage(this.error);
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
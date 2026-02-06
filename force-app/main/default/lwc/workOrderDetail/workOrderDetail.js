import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import getWorkOrderDetail from '@salesforce/apex/WorkOrderDetailController.getWorkOrderDetail';
import createInvoiceForWorkOrder from '@salesforce/apex/WorkOrderInvoiceController.createInvoiceForWorkOrder';
import getServiceCatalog from '@salesforce/apex/WorkOrderDetailController.getServiceCatalog';
import getProductCatalog from '@salesforce/apex/WorkOrderDetailController.getProductCatalog';
import addWorkOrderLineItem from '@salesforce/apex/WorkOrderDetailController.addWorkOrderLineItem';
import deleteWorkOrderLineItem from '@salesforce/apex/WorkOrderDetailController.deleteWorkOrderLineItem';

const ROW_ACTIONS = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' }
];

const COLUMNS = [
    { label: 'Line Type', fieldName: 'lineType' },
    { label: 'Name', fieldName: 'name' },
    { label: 'Units', fieldName: 'units', type: 'number' },
    { label: 'Price', fieldName: 'price', type: 'currency' },
    { label: 'Tax', fieldName: 'tax', type: 'percent' },
    { label: 'Gross Line Total', fieldName: 'grossLineTotal', type: 'currency' },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

const SERVICE_CATALOG_ROW_ACTIONS = [{ label: 'Select', name: 'select' }];
const SERVICE_CATALOG_COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Description', fieldName: 'Description' },
    { label: 'Net Price', fieldName: 'NetPrice', type: 'currency' },
    { label: 'Tax Rate', fieldName: 'TaxRate', type: 'percent' },
    { label: 'Gross Price', fieldName: 'GrossPrice', type: 'currency' },
    { type: 'action', typeAttributes: { rowActions: SERVICE_CATALOG_ROW_ACTIONS } }
];

const PRODUCT_CATALOG_ROW_ACTIONS = [{ label: 'Select', name: 'select' }];
const PRODUCT_CATALOG_COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Description', fieldName: 'Description' },
    { label: 'Net Price', fieldName: 'NetPrice', type: 'currency' },
    { label: 'Tax Rate', fieldName: 'TaxRate', type: 'percent' },
    { label: 'Gross Price', fieldName: 'GrossPrice', type: 'currency' },
    { type: 'action', typeAttributes: { rowActions: PRODUCT_CATALOG_ROW_ACTIONS } }
];

export default class WorkOrderDetail extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    serviceCatalogColumns = SERVICE_CATALOG_COLUMNS;
    productCatalogColumns = PRODUCT_CATALOG_COLUMNS;

    @api workOrderId;
    pageWorkOrderId;
    detail;
    error;
    wiredDetailResult;

    isAddServiceOpen = false;
    isAddProductOpen = false;
    addServiceStep = 'list';
    addProductStep = 'list';
    serviceCatalog = [];
    productCatalog = [];
    selectedServiceItemForAdd = null;
    selectedProductItemForAdd = null;
    quantityForAdd = 1;
    serviceFilterName = '';
    serviceFilterDescription = '';
    productFilterName = '';
    productFilterDescription = '';
    addServiceError;
    addProductError;

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        const workOrderId = pageRef?.state?.c__workOrderId;
        if (workOrderId) {
            this.pageWorkOrderId = workOrderId;
        }
    }

    @wire(getWorkOrderDetail, { workOrderId: '$effectiveWorkOrderId' })
    wiredDetail(result) {
        this.wiredDetailResult = result;
        const { data, error } = result;
        if (data) {
            this.detail = data;
            this.error = undefined;
        } else if (error) {
            this.detail = undefined;
            this.error = error;
        }
    }

    @wire(getServiceCatalog)
    wiredServiceCatalog({ data, error }) {
        if (data) {
            this.serviceCatalog = data;
        } else {
            this.serviceCatalog = [];
        }
    }

    @wire(getProductCatalog)
    wiredProductCatalog({ data, error }) {
        if (data) {
            this.productCatalog = data;
        } else {
            this.productCatalog = [];
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

    get filteredServiceCatalog() {
        const name = (this.serviceFilterName || '').trim().toLowerCase();
        const desc = (this.serviceFilterDescription || '').trim().toLowerCase();
        if (!name && !desc) return this.serviceCatalog;
        return this.serviceCatalog.filter((s) => {
            const n = (s.Name || '').toLowerCase();
            const d = (s.Description || '').toLowerCase();
            return (!name || n.includes(name)) && (!desc || d.includes(desc));
        });
    }

    get filteredProductCatalog() {
        const name = (this.productFilterName || '').trim().toLowerCase();
        const desc = (this.productFilterDescription || '').trim().toLowerCase();
        if (!name && !desc) return this.productCatalog;
        return this.productCatalog.filter((p) => {
            const n = (p.Name || '').toLowerCase();
            const d = (p.Description || '').toLowerCase();
            return (!name || n.includes(name)) && (!desc || d.includes(desc));
        });
    }

    get isAddServiceListStep() {
        return this.addServiceStep === 'list';
    }

    get isAddServiceDetailStep() {
        return this.addServiceStep === 'detail';
    }

    get isAddProductListStep() {
        return this.addProductStep === 'list';
    }

    get isAddProductDetailStep() {
        return this.addProductStep === 'detail';
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleCreateInvoice() {
        if (!this.effectiveWorkOrderId) return;
        this.dispatchEvent(
            new ShowToastEvent({ title: 'Creating invoice...', variant: 'info' })
        );
        try {
            const invoiceId = await createInvoiceForWorkOrder({
                workOrderId: this.effectiveWorkOrderId
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invoice created',
                    message: `Invoice created from Work Order ${this.detail?.workOrderName}.`,
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDetailResult);
            this.dispatchEvent(new CustomEvent('statuschange'));
        } catch (err) {
            const msg = this.getErrorMessage(err);
            const hint =
                msg &&
                (msg.toLowerCase().includes('assigned') ||
                    msg.toLowerCase().includes('employee') ||
                    msg.toLowerCase().includes('required'))
                    ? ' Przypisz pracownika (Assigned Employee) do zlecenia i spróbuj ponownie.'
                    : '';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Conversion failed',
                    message: msg + hint,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        }
    }

    handleAddService() {
        this.addServiceStep = 'list';
        this.selectedServiceItemForAdd = null;
        this.serviceFilterName = '';
        this.serviceFilterDescription = '';
        this.quantityForAdd = 1;
        this.isAddServiceOpen = true;
        this.addServiceError = undefined;
    }

    handleAddProduct() {
        this.addProductStep = 'list';
        this.selectedProductItemForAdd = null;
        this.productFilterName = '';
        this.productFilterDescription = '';
        this.quantityForAdd = 1;
        this.isAddProductOpen = true;
        this.addProductError = undefined;
    }

    handleServiceFilterNameChange(event) {
        this.serviceFilterName = event.target.value || '';
    }

    handleServiceFilterDescriptionChange(event) {
        this.serviceFilterDescription = event.target.value || '';
    }

    handleProductFilterNameChange(event) {
        this.productFilterName = event.target.value || '';
    }

    handleProductFilterDescriptionChange(event) {
        this.productFilterDescription = event.target.value || '';
    }

    handleServiceRowAction(event) {
        if (event.detail.action.name !== 'select') return;
        const rowId = event.detail.row.Id;
        const item = this.serviceCatalog.find((s) => s.Id === rowId);
        if (!item) return;
        this.selectedServiceItemForAdd = item;
        this.quantityForAdd =
            item.DefaultLabourHours != null ? Number(item.DefaultLabourHours) || 1 : 1;
        this.addServiceStep = 'detail';
        this.addServiceError = undefined;
    }

    handleProductRowAction(event) {
        if (event.detail.action.name !== 'select') return;
        const rowId = event.detail.row.Id;
        const item = this.productCatalog.find((p) => p.Id === rowId);
        if (!item) return;
        this.selectedProductItemForAdd = item;
        this.quantityForAdd = 1;
        this.addProductStep = 'detail';
        this.addProductError = undefined;
    }

    handleBackToServiceList() {
        this.addServiceStep = 'list';
        this.selectedServiceItemForAdd = null;
        this.addServiceError = undefined;
    }

    handleBackToProductList() {
        this.addProductStep = 'list';
        this.selectedProductItemForAdd = null;
        this.addProductError = undefined;
    }

    handleQuantityChange(event) {
        const val = parseFloat(event.target.value, 10);
        this.quantityForAdd = isNaN(val) || val < 0 ? 0 : val;
    }

    async handleConfirmAddService() {
        const item = this.selectedServiceItemForAdd;
        if (!item) {
            this.addServiceError = 'Select a service.';
            return;
        }
        if (!this.quantityForAdd || this.quantityForAdd <= 0) {
            this.addServiceError = 'Enter a valid quantity (hours).';
            return;
        }
        try {
            await addWorkOrderLineItem({
                workOrderId: this.effectiveWorkOrderId,
                lineType: 'Service',
                productId: null,
                serviceId: item.Id,
                quantity: this.quantityForAdd,
                unitPrice: item.NetPrice,
                taxRate: item.TaxRate != null ? item.TaxRate : 0
            });
            this.isAddServiceOpen = false;
            this.addServiceStep = 'list';
            this.selectedServiceItemForAdd = null;
            await refreshApex(this.wiredDetailResult);
            this.dispatchEvent(new CustomEvent('statuschange'));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Line added',
                    message: 'Service line added.',
                    variant: 'success'
                })
            );
        } catch (err) {
            this.addServiceError = this.getErrorMessage(err);
        }
    }

    async handleConfirmAddProduct() {
        const item = this.selectedProductItemForAdd;
        if (!item) {
            this.addProductError = 'Select a product.';
            return;
        }
        if (!this.quantityForAdd || this.quantityForAdd <= 0) {
            this.addProductError = 'Enter a valid quantity.';
            return;
        }
        try {
            await addWorkOrderLineItem({
                workOrderId: this.effectiveWorkOrderId,
                lineType: 'Product',
                productId: item.Id,
                serviceId: null,
                quantity: this.quantityForAdd,
                unitPrice: item.NetPrice,
                taxRate: item.TaxRate != null ? item.TaxRate : 0
            });
            this.isAddProductOpen = false;
            this.addProductStep = 'list';
            this.selectedProductItemForAdd = null;
            await refreshApex(this.wiredDetailResult);
            this.dispatchEvent(new CustomEvent('statuschange'));
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Line added',
                    message: 'Product line added.',
                    variant: 'success'
                })
            );
        } catch (err) {
            this.addProductError = this.getErrorMessage(err);
        }
    }

    handleCancelAddService() {
        this.isAddServiceOpen = false;
        this.addServiceStep = 'list';
        this.selectedServiceItemForAdd = null;
        this.addServiceError = undefined;
    }

    handleCancelAddProduct() {
        this.isAddProductOpen = false;
        this.addProductStep = 'list';
        this.selectedProductItemForAdd = null;
        this.addProductError = undefined;
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            const confirmed = await LightningConfirm.open({
                message: 'Remove this line item from the work order?',
                label: 'Confirm delete'
            });
            if (!confirmed) return;
            try {
                await deleteWorkOrderLineItem({ lineItemId: row.lineItemId });
                await refreshApex(this.wiredDetailResult);
                this.dispatchEvent(new CustomEvent('statuschange'));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Line removed',
                        variant: 'success'
                    })
                );
            } catch (err) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Delete failed',
                        message: this.getErrorMessage(err),
                        variant: 'error'
                    })
                );
            }
            return;
        }

        if (actionName === 'edit') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.lineItemId,
                    objectApiName: 'Work_Order_Line_Item__c',
                    actionName: 'edit'
                }
            });
        }
    }

    getErrorMessage(error) {
        if (!error) return '';
        const body = error.body;
        if (body) {
            if (typeof body.message === 'string') return body.message;
            if (Array.isArray(body)) {
                return body.map((item) => item.message || item).join(', ');
            }
            if (Array.isArray(body.pageErrors)) {
                return body.pageErrors.map((e) => e.message || e).join(', ');
            }
            if (body.fieldErrors) {
                const msgs = [];
                Object.keys(body.fieldErrors).forEach((field) => {
                    const arr = body.fieldErrors[field];
                    if (Array.isArray(arr)) {
                        arr.forEach((e) => msgs.push((e.message || e).toString()));
                    }
                });
                if (msgs.length) return msgs.join(', ');
            }
        }
        return error.message || 'Unknown error';
    }
}

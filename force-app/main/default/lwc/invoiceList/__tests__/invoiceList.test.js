import { createElement } from '@lwc/engine-dom';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import InvoiceList from 'c/invoiceList';

const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');

const getInvoicesAdapter = createApexTestWireAdapter();
const getCreatedByOptionsAdapter = createApexTestWireAdapter();
const getAccountOptionsAdapter = createApexTestWireAdapter();

jest.mock(
    '@salesforce/apex/WorkOrderInvoiceController.getInvoices',
    () => ({
        default: getInvoicesAdapter
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/WorkOrderInvoiceController.getInvoiceCreatedByOptions',
    () => ({
        default: getCreatedByOptionsAdapter
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/WorkOrderInvoiceController.getInvoiceAccountOptions',
    () => ({
        default: getAccountOptionsAdapter
    }),
    { virtual: true }
);

const INVOICES = [
    {
        Id: 'a01xx0000000001AAA',
        Name: 'INV-0001',
        CreatedDate: '2025-02-01T10:00:00.000Z',
        CreatedBy: { Name: 'Test User' },
        Invoice_Net_Total__c: 120.5,
        Invoice_Status__c: 'Draft',
        Work_Order__r: { Visit__r: { Account__r: { Name: 'ACME' } } }
    },
    {
        Id: 'a01xx0000000002AAA',
        Name: 'INV-0002',
        CreatedDate: '2025-02-02T10:00:00.000Z',
        CreatedBy: { Name: 'Test User' },
        Invoice_Net_Total__c: 99.9,
        Invoice_Status__c: 'Issued',
        Work_Order__r: { Visit__r: { Account__r: { Name: 'Globex' } } }
    },
    {
        Id: 'a01xx0000000003AAA',
        Name: 'INV-0003',
        CreatedDate: '2025-02-03T10:00:00.000Z',
        CreatedBy: { Name: 'Test User' },
        Invoice_Net_Total__c: 10,
        Invoice_Status__c: 'Paid',
        Work_Order__r: { Visit__r: { Account__r: { Name: 'Initech' } } }
    }
];

const CREATED_BY_OPTIONS = [{ label: 'Test User', value: '005xx0000000001AAA' }];
const ACCOUNT_OPTIONS = [{ label: 'ACME', value: '001xx0000000001AAA' }];

const flushPromises = () => Promise.resolve();

jest.mock(
    '@salesforce/apex/WorkOrderInvoiceController.updateInvoiceStatus',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    'lightning/confirm',
    () => ({
        open: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex',
    () => ({
        refreshApex: jest.fn()
    }),
    { virtual: true }
);

describe('c-invoice-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders datatable rows and filter options', async () => {
        const element = createElement('c-invoice-list', { is: InvoiceList });
        document.body.appendChild(element);

        getCreatedByOptionsAdapter.emit(CREATED_BY_OPTIONS);
        getAccountOptionsAdapter.emit(ACCOUNT_OPTIONS);
        getInvoicesAdapter.emit(INVOICES);

        await flushPromises();

        const dataTable = element.shadowRoot.querySelector('lightning-datatable');
        expect(dataTable).not.toBeNull();
        expect(dataTable.data).toHaveLength(3);
        expect(dataTable.data[0].Name).toBe('INV-0001');
        expect(dataTable.data[0].createdByName).toBe('Test User');
        expect(dataTable.data[0].accountName).toBe('ACME');
        expect(dataTable.data[0].availableActions.map((item) => item.name)).toEqual([
            'approve',
            'void'
        ]);
        expect(dataTable.data[1].availableActions.map((item) => item.name)).toEqual([
            'paid',
            'void'
        ]);
        expect(dataTable.data[2].availableActions.map((item) => item.name)).toEqual(['void']);

        const comboBoxes = element.shadowRoot.querySelectorAll('lightning-combobox');
        expect(comboBoxes).toHaveLength(2);
        expect(comboBoxes[0].options[0].label).toBe('All');
        expect(comboBoxes[1].options[0].label).toBe('All');

        const viewColumn = dataTable.columns.find((column) => column.type === 'button');
        expect(viewColumn).toBeDefined();
        expect(viewColumn.label).toBe('View');
    });

    it('shows an error message when invoice wire fails', async () => {
        const element = createElement('c-invoice-list', { is: InvoiceList });
        document.body.appendChild(element);

        getInvoicesAdapter.error({ body: { message: 'Wire error' } });
        await flushPromises();

        const errorMessage = element.shadowRoot.querySelector('.slds-text-color_error');
        expect(errorMessage).not.toBeNull();
        expect(errorMessage.textContent).toContain('Wire error');
    });

    it('updates status after confirmation', async () => {
        const updateInvoiceStatus = require('@salesforce/apex/WorkOrderInvoiceController.updateInvoiceStatus')
            .default;
        LightningConfirm.open.mockResolvedValue(true);

        const element = createElement('c-invoice-list', { is: InvoiceList });
        document.body.appendChild(element);

        getInvoicesAdapter.emit(INVOICES);
        await flushPromises();

        const dataTable = element.shadowRoot.querySelector('lightning-datatable');
        dataTable.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: {
                    action: { name: 'approve' },
                    row: dataTable.data[0]
                }
            })
        );

        await flushPromises();

        expect(LightningConfirm.open).toHaveBeenCalled();
        expect(updateInvoiceStatus).toHaveBeenCalledWith({
            invoiceId: 'a01xx0000000001AAA',
            newStatus: 'Issued'
        });
        expect(refreshApex).toHaveBeenCalled();
    });

    it('opens invoice detail modal on view action', async () => {
        const element = createElement('c-invoice-list', { is: InvoiceList });
        document.body.appendChild(element);

        getInvoicesAdapter.emit(INVOICES);
        await flushPromises();

        const dataTable = element.shadowRoot.querySelector('lightning-datatable');
        dataTable.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: {
                    action: { name: 'view' },
                    row: dataTable.data[0]
                }
            })
        );

        await flushPromises();
        const detail = element.shadowRoot.querySelector('c-invoice-detail');
        expect(detail).not.toBeNull();
    });
});

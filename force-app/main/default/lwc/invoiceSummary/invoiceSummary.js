import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Invoice__c.Name',
    'Invoice__c.Invoice_Status__c',
    'Invoice__c.Invoice_Net_Total__c',
    'Invoice__c.Invoice_Gross_Total__c'
];

export default class InvoiceSummary extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    invoice;

    get hasData() {
        return this.invoice && this.invoice.data;
    }

    get invoiceNumber() {
        return this.invoice?.data?.fields?.Name?.value ?? '—';
    }

    get status() {
        return this.invoice?.data?.fields?.Invoice_Status__c?.value ?? '—';
    }

    get netTotal() {
        return this.invoice?.data?.fields?.Invoice_Net_Total__c?.value ?? '—';
    }

    get grossTotal() {
        return this.invoice?.data?.fields?.Invoice_Gross_Total__c?.value ?? '—';
    }
}

/*
@api recordId - Salesforce automatycznie przekazuje ID rekordu

@wire(getRecord...) - pobieranie danych bez Apex, przez UI API

FIELDS - jawnie wskazane pola = bezpieczeństwo + wydajność

get ...() - gettery do bindowania w HTML
*/
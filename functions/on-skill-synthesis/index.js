const { BigQuery } = require('@google-cloud/bigquery');
const bigquery = new BigQuery();

/**
 * Triggered from a message on a Cloud Pub/Sub topic (ecosystem-events).
 *
 * @param {object} message The Pub/Sub message.
 * @param {object} context The event metadata.
 */
exports.processEcosystemEvent = async (message, context) => {
    try {
        const data = message.data ? Buffer.from(message.data, 'base64').toString() : '{}';
        const event = JSON.parse(data);
        
        console.log(`[ECOSYSTEM] Received event: ${event.eventType || 'UNKNOWN'}`);

        // Insert into BigQuery
        const datasetId = 'cerebro_ecosystem';
        const tableId = 'ecosystem_metrics';
        
        const row = {
            metric_id: context.eventId,
            timestamp: bigquery.datetime(new Date(context.timestamp).toISOString()),
            metric_name: event.eventType || 'SYSTEM_EVENT',
            metric_value: event.value ? parseFloat(event.value) : 1.0,
            unit: event.unit || 'count',
            source_system: event.source || 'scheduler',
            metadata: JSON.stringify(event.data || {})
        };
        
        await bigquery.dataset(datasetId).table(tableId).insert([row]);
        console.log(`[ECOSYSTEM] Event ${context.eventId} persisted to BigQuery.`);
        
        // Execute conditional business logic based on the scheduled event
        if (event.eventType === 'scheduled_nightly_audit') {
            console.log(`[AUDIT] Starting Nightly Ecosystem Audit...`);
            // Place logic for analyzing skills and determining synthesis needs here.
        } else if (event.eventType === 'scheduled_health_check') {
            console.log(`[HEALTH] Performing Hourly Health Check...`);
            // Place logic to ping API Gateway and other endpoints here.
        }

    } catch (error) {
        console.error(`[ERROR] Failed to process ecosystem event: ${error.message}`);
        throw error;
    }
};

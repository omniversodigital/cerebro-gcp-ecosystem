const { BigQuery } = require('@google-cloud/bigquery');
const bigquery = new BigQuery();

/**
 * Triggered from a message on a Cloud Pub/Sub topic.
 *
 * @param {object} message The Pub/Sub message.
 * @param {object} context The event metadata.
 */
exports.processSecurityEvent = async (message, context) => {
    try {
        const data = message.data ? Buffer.from(message.data, 'base64').toString() : '{}';
        const event = JSON.parse(data);
        
        console.log(`[SECURITY] Received event from ${event.source || 'UNKNOWN'}: ${event.description || 'No description'}`);

        // Insert into BigQuery
        const datasetId = 'cerebro_ecosystem';
        const tableId = 'security_events';
        
        const row = {
            event_id: context.eventId,
            timestamp: bigquery.datetime(new Date(context.timestamp).toISOString()),
            severity: event.severity || 'WARNING',
            source_system: event.source || 'PUB/SUB',
            description: event.description || '',
            action_taken: event.action_taken || 'LOGGED',
            metadata: JSON.stringify(event.metadata || {})
        };
        
        await bigquery.dataset(datasetId).table(tableId).insert([row]);
        console.log(`[SECURITY] Event ${context.eventId} persisted to BigQuery.`);
        
    } catch (error) {
        console.error(`[ERROR] Failed to process security event: ${error.message}`);
        // Let it throw so Pub/Sub can retry if necessary
        throw error;
    }
};

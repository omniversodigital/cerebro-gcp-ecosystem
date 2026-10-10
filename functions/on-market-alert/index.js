const { BigQuery } = require('@google-cloud/bigquery');
const bigquery = new BigQuery();

/**
 * Triggered from a message on a Cloud Pub/Sub topic.
 *
 * @param {object} message The Pub/Sub message.
 * @param {object} context The event metadata.
 */
exports.processMarketSignal = async (message, context) => {
    try {
        const data = message.data ? Buffer.from(message.data, 'base64').toString() : '{}';
        const signal = JSON.parse(data);
        
        console.log(`[MARKET] Received signal for ${signal.asset || 'UNKNOWN'}: ${signal.direction || 'NONE'} (${signal.confidence || 0}%)`);

        // Insert into BigQuery
        const datasetId = 'cerebro_ecosystem';
        const tableId = 'market_signals';
        
        const row = {
            signal_id: context.eventId,
            timestamp: bigquery.datetime(new Date(context.timestamp).toISOString()),
            asset_pair: signal.asset || 'UNKNOWN',
            signal_type: signal.direction || 'NEUTRAL',
            confidence_score: parseFloat(signal.confidence || 0.0),
            source_model: signal.source || 'UNKNOWN',
            raw_payload: JSON.stringify(signal.payload || {})
        };
        
        await bigquery.dataset(datasetId).table(tableId).insert([row]);
        console.log(`[MARKET] Signal ${context.eventId} persisted to BigQuery.`);
        
    } catch (error) {
        console.error(`[ERROR] Failed to process market signal: ${error.message}`);
        throw error;
    }
};

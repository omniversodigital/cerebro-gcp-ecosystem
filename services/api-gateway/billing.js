/**
 * CEREBRO API Gateway - Stripe Billing & Subscription Module
 */
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY || 'sk_test_mock_key');

const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';

/**
 * Create a Stripe Checkout Session for subscription/credit purchase.
 */
async function createCheckoutSession(priceId, customerEmail, successUrl, cancelUrl) {
  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'subscription',
      customer_email: customerEmail,
      line_items: [{
        price: priceId,
        quantity: 1,
      }],
      success_url: successUrl || 'https://omniverso.digital/success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: cancelUrl || 'https://omniverso.digital/canceled',
    });
    return session;
  } catch (err) {
    console.error('[Billing Module Error]:', err.message);
    throw err;
  }
}

/**
 * Verify and process incoming Stripe HMAC Webhooks.
 */
function handleStripeWebhook(rawBody, signature) {
  if (!STRIPE_WEBHOOK_SECRET) {
    console.warn('[Billing Warning] STRIPE_WEBHOOK_SECRET not configured. Skipping HMAC verification.');
    return JSON.parse(rawBody);
  }

  try {
    const event = stripe.webhooks.constructEvent(rawBody, signature, STRIPE_WEBHOOK_SECRET);
    return event;
  } catch (err) {
    console.error('[Billing Security Alert] Invalid Webhook Signature:', err.message);
    throw new Error(`Webhook Error: ${err.message}`);
  }
}

module.exports = {
  createCheckoutSession,
  handleStripeWebhook
};

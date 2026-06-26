import crypto from 'crypto';

// Razorpay configuration
const razorpayKeyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID!;
const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET!;

// Validate that required env vars are present
if (!razorpayKeyId || !razorpayKeySecret) {
  console.warn('Razorpay credentials not configured. Payment features will be disabled.');
}

export interface RazorpayOrder {
  id: string;
  entity: string;
  amount: number;
  amount_paid: number;
  amount_due: number;
  currency: string;
  receipt: string;
  status: string;
  created_at: number;
}

export interface RazorpayPaymentVerification {
  razorpay_order_id: string;
  razorpay_payment_id: string;
  razorpay_signature: string;
}

/**
 * Create a new Razorpay order
 * @param amount - Amount in paise (1 INR = 100 paise)
 * @param receiptId - Unique receipt ID for tracking
 * @param customerDetails - Optional customer details
 */
export async function createRazorpayOrder(
  amount: number,
  receiptId: string,
  customerDetails?: {
    name?: string;
    email?: string;
    phone?: string;
  }
): Promise<RazorpayOrder | null> {
  if (!razorpayKeyId || !razorpayKeySecret) {
    console.error('Razorpay credentials not configured');
    return null;
  }

  try {
    // Razorpay API endpoint for creating orders
    const url = 'https://api.razorpay.com/v1/orders';
    
    // Create auth header using Basic Auth (key_id:key_secret in base64)
    const auth = Buffer.from(`${razorpayKeyId}:${razorpayKeySecret}`).toString('base64');
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount,
        currency: 'INR',
        receipt: receiptId,
        notes: {
          ...(customerDetails?.name && { customer_name: customerDetails.name }),
          ...(customerDetails?.email && { customer_email: customerDetails.email }),
          ...(customerDetails?.phone && { customer_phone: customerDetails.phone }),
        },
      }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('Razorpay order creation failed:', errorData);
      throw new Error(errorData.description || 'Failed to create Razorpay order');
    }

    const order = await response.json();
    return order as RazorpayOrder;
  } catch (error) {
    console.error('Error creating Razorpay order:', error);
    return null;
  }
}

/**
 * Verify Razorpay payment signature
 * @param params - Payment verification parameters
 * @returns boolean indicating if signature is valid
 */
export function verifyRazorpaySignature(params: RazorpayPaymentVerification): boolean {
  if (!razorpayKeySecret) {
    console.error('Razorpay secret not configured');
    return false;
  }

  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = params;
    
    // Create the expected signature
    const sign = razorpay_order_id + '|' + razorpay_payment_id;
    const expectedSign = crypto
      .createHmac('sha256', razorpayKeySecret)
      .update(sign.toString())
      .digest('hex');
    
    // Compare signatures
    return crypto.timingSafeEqual(
      Buffer.from(expectedSign),
      Buffer.from(razorpay_signature)
    );
  } catch (error) {
    console.error('Error verifying Razorpay signature:', error);
    return false;
  }
}

/**
 * Fetch Razorpay payment details
 * @param paymentId - Razorpay payment ID
 */
export async function fetchRazorpayPayment(paymentId: string): Promise<any | null> {
  if (!razorpayKeyId || !razorpayKeySecret) {
    console.error('Razorpay credentials not configured');
    return null;
  }

  try {
    const url = `https://api.razorpay.com/v1/payments/${paymentId}`;
    const auth = Buffer.from(`${razorpayKeyId}:${razorpayKeySecret}`).toString('base64');
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('Failed to fetch payment details:', errorData);
      return null;
    }

    return await response.json();
  } catch (error) {
    console.error('Error fetching Razorpay payment:', error);
    return null;
  }
}

/**
 * Generate unique receipt ID for Razorpay orders
 */
export function generateReceiptId(prefix: string = 'LASTEY'): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `${prefix}_${timestamp}_${random}`;
}

/**
 * Convert INR to paise (Razorpay expects amounts in paise)
 * @param amountInRupees - Amount in Indian Rupees
 */
export function toPaise(amountInRupees: number): number {
  return Math.round(amountInRupees * 100);
}

/**
 * Convert paise to INR
 * @param amountInPaise - Amount in paise
 */
export function toRupees(amountInPaise: number): number {
  return amountInPaise / 100;
}

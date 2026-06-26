import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Server-side client with service role key (for API routes only)
export const createServerClient = () => {
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
};

// Type definitions
export type UserRole = 'ADMIN' | 'OWNER' | 'CUSTOMER';
export type VerificationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
export type BookingStatus = 'PENDING' | 'CONFIRMED' | 'CANCELLED' | 'COMPLETED';

export interface User {
  id: string;
  email: string;
  phone?: string;
  full_name: string;
  role: UserRole;
  created_at: string;
  updated_at: string;
}

export interface Hostel {
  id: string;
  owner_id: string;
  name: string;
  description?: string;
  address: string;
  city: 'Haridwar' | 'Rishikesh';
  state?: string;
  pincode?: string;
  latitude?: number;
  longitude?: number;
  total_beds: number;
  amenities?: string[];
  images?: string[];
  base_price: number;
  verification_status: VerificationStatus;
  admin_notes?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Inventory {
  id: string;
  hostel_id: string;
  date: string;
  total_beds: number;
  available_beds: number;
  base_price: number;
  is_flash_sale: boolean;
  flash_price?: number;
  created_at: string;
  updated_at: string;
}

export interface Booking {
  id: string;
  customer_id: string;
  hostel_id: string;
  check_in_date: string;
  check_out_date: string;
  beds_booked: number;
  total_amount: number;
  flash_sale_applied: boolean;
  discount_amount?: number;
  status: BookingStatus;
  razorpay_order_id?: string;
  razorpay_payment_id?: string;
  razorpay_signature?: string;
  customer_name: string;
  customer_phone: string;
  customer_email: string;
  special_requests?: string;
  created_at: string;
  updated_at: string;
}

export interface AdminVerificationLog {
  id: string;
  hostel_id: string;
  admin_id: string;
  action: 'APPROVED' | 'REJECTED';
  notes?: string;
  created_at: string;
}

export interface Notification {
  id: string;
  user_id: string;
  title: string;
  message: string;
  type: 'VERIFICATION' | 'BOOKING' | 'FLASH_SALE' | 'SYSTEM';
  is_read: boolean;
  created_at: string;
}

// Helper functions
export async function getUserRole(userId: string): Promise<UserRole | null> {
  const { data, error } = await supabase
    .from('users')
    .select('role')
    .eq('id', userId)
    .single();

  if (error || !data) {
    return null;
  }

  return data.role;
}

export async function isAdmin(userId: string): Promise<boolean> {
  const role = await getUserRole(userId);
  return role === 'ADMIN';
}

export async function isOwner(userId: string): Promise<boolean> {
  const role = await getUserRole(userId);
  return role === 'OWNER';
}

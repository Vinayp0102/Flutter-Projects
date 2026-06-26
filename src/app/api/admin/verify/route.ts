import { NextRequest, NextResponse } from 'next/server';
import { createServerClient, isAdmin } from '@/lib/supabase';

const RESEND_API_KEY = process.env.RESEND_API_KEY;

/**
 * POST /api/admin/verify
 * Approve or reject a hostel verification request
 * 
 * Body:
 * {
 *   hostelId: string,
 *   action: 'APPROVED' | 'REJECTED',
 *   adminNotes?: string
 * }
 */
export async function POST(request: NextRequest) {
  try {
    // Get auth header from request
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized: Missing authentication token' },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    // Create server client with service role
    const supabase = createServerClient();

    // Verify the token and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized: Invalid token' },
        { status: 401 }
      );
    }

    // Check if user is admin
    const userIsAdmin = await isAdmin(user.id);
    if (!userIsAdmin) {
      return NextResponse.json(
        { error: 'Forbidden: Admin access required' },
        { status: 403 }
      );
    }

    // Parse request body
    const body = await request.json();
    const { hostelId, action, adminNotes } = body;

    // Validate input
    if (!hostelId || !action) {
      return NextResponse.json(
        { error: 'Bad Request: hostelId and action are required' },
        { status: 400 }
      );
    }

    if (!['APPROVED', 'REJECTED'].includes(action)) {
      return NextResponse.json(
        { error: 'Bad Request: action must be APPROVED or REJECTED' },
        { status: 400 }
      );
    }

    // Start a transaction-like operation
    // 1. Update hostel verification status
    const updateData: any = {
      verification_status: action === 'APPROVED' ? 'APPROVED' : 'REJECTED',
      admin_notes: adminNotes || null,
      is_active: action === 'APPROVED',
    };

    const { error: updateError } = await supabase
      .from('hostels')
      .update(updateData)
      .eq('id', hostelId);

    if (updateError) {
      console.error('Database update error:', updateError);
      return NextResponse.json(
        { error: 'Failed to update hostel verification status' },
        { status: 500 }
      );
    }

    // 2. Log the verification action
    const { error: logError } = await supabase
      .from('admin_verification_log')
      .insert({
        hostel_id: hostelId,
        admin_id: user.id,
        action: action,
        notes: adminNotes,
      });

    if (logError) {
      console.error('Failed to log verification action:', logError);
      // Continue anyway as the main update succeeded
    }

    // 3. Get hostel owner details for notification
    const { data: hostelData } = await supabase
      .from('hostels')
      .select('owner_id, name')
      .eq('id', hostelId)
      .single();

    if (hostelData) {
      // 4. Create notification for owner
      await supabase.from('notifications').insert({
        user_id: hostelData.owner_id,
        title: action === 'APPROVED' ? 'Hostel Approved! 🎉' : 'Hostel Verification Update',
        message: action === 'APPROVED'
          ? `Your hostel "${hostelData.name}" has been approved and is now live on Lastey!`
          : `Your hostel "${hostelData.name}" verification was rejected. ${adminNotes ? 'Note: ' + adminNotes : 'Please contact support for details.'}`,
        type: 'VERIFICATION',
      });

      // 5. Send email via Resend (if configured)
      if (RESEND_API_KEY && action === 'APPROVED') {
        try {
          const { data: ownerData } = await supabase
            .from('users')
            .select('email, full_name')
            .eq('id', hostelData.owner_id)
            .single();

          if (ownerData?.email) {
            await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${RESEND_API_KEY}`,
              },
              body: JSON.stringify({
                from: 'Lastey Admin <noreply@lastey.com>',
                to: ownerData.email,
                subject: action === 'APPROVED' ? '🎉 Your Hostel is Approved on Lastey!' : 'Hostel Verification Update',
                html: `
                  <h1>${action === 'APPROVED' ? 'Congratulations!' : 'Verification Update'}</h1>
                  <p>Dear ${ownerData.full_name},</p>
                  <p>Your hostel <strong>${hostelData.name}</strong> has been ${action.toLowerCase()}.</p>
                  ${action === 'APPROVED' ? `
                    <p>Your hostel is now live on Lastey and visible to customers!</p>
                    <p>You can now:</p>
                    <ul>
                      <li>Manage your inventory and pricing</li>
                      <li>Activate flash sales for last-minute bookings</li>
                      <li>Receive and manage bookings</li>
                    </ul>
                    <p>Thank you for joining Lastey!</p>
                  ` : `
                    ${adminNotes ? `<p><strong>Admin Notes:</strong> ${adminNotes}</p>` : ''}
                    <p>Please contact our support team if you have questions.</p>
                  `}
                  <p>Best regards,<br>The Lastey Team</p>
                `,
              }),
            });
          }
        } catch (emailError) {
          console.error('Failed to send email notification:', emailError);
          // Continue anyway as the main update succeeded
        }
      }
    }

    return NextResponse.json({
      success: true,
      message: `Hostel ${action.toLowerCase()} successfully`,
      data: {
        hostelId,
        action,
        updatedBy: user.id,
      },
    });

  } catch (error) {
    console.error('Unexpected error in verification API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/admin/verify
 * Fetch all pending verification requests
 */
export async function GET(request: NextRequest) {
  try {
    // Get auth header from request
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized: Missing authentication token' },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    
    // Create server client with service role
    const supabase = createServerClient();

    // Verify the token and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    
    if (authError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized: Invalid token' },
        { status: 401 }
      );
    }

    // Check if user is admin
    const userIsAdmin = await isAdmin(user.id);
    if (!userIsAdmin) {
      return NextResponse.json(
        { error: 'Forbidden: Admin access required' },
        { status: 403 }
      );
    }

    // Fetch pending hostels with owner details
    const { data: hostels, error: fetchError } = await supabase
      .from('hostels')
      .select(`
        id,
        name,
        description,
        address,
        city,
        total_beds,
        base_price,
        amenities,
        images,
        created_at,
        owner_id,
        users (
          email,
          phone,
          full_name
        )
      `)
      .eq('verification_status', 'PENDING')
      .order('created_at', { ascending: false });

    if (fetchError) {
      console.error('Database fetch error:', fetchError);
      return NextResponse.json(
        { error: 'Failed to fetch pending verifications' },
        { status: 500 }
      );
    }

    // Fetch verification logs for these hostels
    const hostelIds = hostels?.map(h => h.id) || [];
    let verificationLogs = [];
    
    if (hostelIds.length > 0) {
      const { data: logs } = await supabase
        .from('admin_verification_log')
        .select('hostel_id, action, notes, created_at')
        .in('hostel_id', hostelIds)
        .order('created_at', { ascending: false });
      
      verificationLogs = logs || [];
    }

    // Format response
    const formattedHostels = hostels?.map(hostel => ({
      id: hostel.id,
      name: hostel.name,
      description: hostel.description,
      address: hostel.address,
      city: hostel.city,
      total_beds: hostel.total_beds,
      base_price: hostel.base_price,
      amenities: hostel.amenities,
      images: hostel.images,
      created_at: hostel.created_at,
      owner: {
        id: hostel.owner_id,
        name: hostel.users?.full_name,
        email: hostel.users?.email,
        phone: hostel.users?.phone,
      },
      previousActions: verificationLogs.filter(log => log.hostel_id === hostel.id),
    }));

    return NextResponse.json({
      success: true,
      data: formattedHostels,
      count: formattedHostels?.length || 0,
    });

  } catch (error) {
    console.error('Unexpected error in fetch verifications API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

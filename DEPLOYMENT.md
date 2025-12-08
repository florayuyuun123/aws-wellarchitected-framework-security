# Deployment Instructions - Admin Backend Migration

## Changes Made

### Backend (Flask on EC2)
- ✅ Added Flask template rendering
- ✅ Added session management
- ✅ Created `/admin/login` route (GET/POST)
- ✅ Created `/admin/dashboard` route (protected)
- ✅ Created `/admin/logout` route
- ✅ Admin pages now served from backend

### Frontend (S3)
- ✅ Removed `admin/` directory
- ✅ Removed `js/admin.js` and `js/dashboard.js`
- ✅ Updated admin links to point to ALB

## Deployment Steps

### 1. Redeploy Infrastructure
```bash
terraform apply
```

This will:
- Create new EC2 instances with updated Flask app
- Admin routes will be available at ALB DNS

### 2. Deploy Website
```bash
# Push to GitHub (triggers workflow)
git add .
git commit -m "Move admin to backend"
git push origin main
```

The workflow will:
- Sync website files to S3
- Replace `ALB_DNS_PLACEHOLDER` with actual ALB DNS in admin links

### 3. Access Points

**Public (S3):**
- Registration: `http://s3-bucket.s3-website-us-east-1.amazonaws.com/index.html`
- Status Check: `http://s3-bucket.s3-website-us-east-1.amazonaws.com/status.html`

**Admin (Backend ALB):**
- Login: `http://alb-dns-name.amazonaws.com/admin/login`
- Dashboard: `http://alb-dns-name.amazonaws.com/admin/dashboard`

### 4. Test Admin Access

```bash
# Get ALB DNS
terraform output alb_dns_name

# Test admin login page
curl http://<ALB_DNS>/admin/login

# Login credentials (demo):
# Username: admin
# Password: admin123
```

### 5. Verify

```bash
# Check backend health
curl http://<ALB_DNS>/health

# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```

## Security Improvements

✅ **Before:** Admin pages on S3 (publicly accessible HTML)
✅ **After:** Admin pages on backend (server-side rendered, session-protected)

**Benefits:**
- Admin HTML not publicly accessible
- Server-side session management
- Protected routes (redirect to login if not authenticated)
- Logout functionality

## Notes

- Admin credentials are hardcoded (demo only)
- Sessions use Flask's secure cookies
- HTTP only (HTTPS requires ACM certificate)
- For production: Add database-backed auth, HTTPS, rate limiting

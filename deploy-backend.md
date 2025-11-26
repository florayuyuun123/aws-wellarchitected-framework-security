# Backend Deployment Steps

## 1. Update Infrastructure
```bash
terraform plan
terraform apply
```

## 2. Get ALB DNS Name
```bash
terraform output alb_dns_name
```

## 3. Update Frontend Configuration
Edit `website/js/config.js` and replace `YOUR_ALB_DNS_NAME` with your actual ALB DNS name.

## 4. Initialize Database
Connect to your RDS instance and run:
```sql
-- Use the init_db.sql file
CREATE TABLE IF NOT EXISTS companies (...);
```

## 5. Deploy Updated Website
Push changes to trigger website deployment workflow.

## 6. Test the Integration
- Frontend: S3 website URL
- Backend API: ALB DNS name
- Database: RDS (private access only)

## API Endpoints
- `POST /api/companies` - Register company
- `GET /api/companies/{reg_number}` - Get company status  
- `GET /api/admin/companies` - Get all companies (admin)
- `PUT /api/admin/companies/{id}/approve` - Approve company
- `PUT /api/admin/companies/{id}/reject` - Reject company
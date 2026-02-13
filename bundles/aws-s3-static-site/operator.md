---
templating: mustache
---

# Static Website Operator Guide

## Your Website

Your static site is live at:

**URL:** `http://{{md_metadata.name_prefix}}-{{params.site_name}}.s3-website-us-east-1.amazonaws.com`

Simply share this URL with anyone who needs to view the page.

---

## Updating Content

To update your website content:

1. Go to your package configuration in Massdriver
2. Edit the **HTML Content** field
3. Click **Deploy**

Changes are live within seconds of deployment completing.

---

## Tips for Marketing Pages

### Adding Images

Host images externally (e.g., on your CDN or image hosting service) and reference them:

```html
<img src="https://your-cdn.com/images/logo.png" alt="Logo">
```

### Adding Styles

Include CSS directly in your HTML:

```html
<style>
  .hero { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
  .cta-button { background: #ff6b6b; color: white; padding: 15px 30px; }
</style>
```

### Adding Analytics

Add your tracking snippet before `</body>`:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_TRACKING_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_TRACKING_ID');
</script>
```

---

## Limitations

- **No HTTPS** - S3 website hosting is HTTP only. For HTTPS, use CloudFront (contact platform team)
- **No custom domain** - Uses AWS-provided URL. For custom domains, contact platform team
- **Single page** - This bundle hosts one page. For multi-page sites, contact platform team

---

## Troubleshooting

### Page not loading?

1. Wait 1-2 minutes after deployment for S3 to propagate
2. Check the deployment logs in Massdriver for errors
3. Verify your HTML is valid (missing closing tags can cause issues)

### Content not updating?

1. Hard refresh your browser (Ctrl+Shift+R or Cmd+Shift+R)
2. Ensure the deployment completed successfully
3. Check that you saved your changes before deploying

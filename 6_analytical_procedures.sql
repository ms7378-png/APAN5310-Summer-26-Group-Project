-- ============================================================
-- Dream Homes NYC Analytical Procedures (10 Complex Business Queries)
-- CTE Pre-aggregated Financial Metrics - Final Parity Version
-- Dynamic Commission & Geographical School Alignment Version
-- ============================================================

-- PROCEDURE 1: Agent Net Profit Scorecard
WITH rev_cte AS (
    SELECT transaction_id, SUM(amount) AS gross_rev
    FROM revenues GROUP BY transaction_id
),
exp_cte AS (
    SELECT transaction_id, SUM(amount) AS total_exp
    FROM expenses GROUP BY transaction_id
)
SELECT 
    a.first_name || ' ' || a.last_name AS agent_name,
    o.office_name,
    COUNT(t.transaction_id) AS closed_deals,
    SUM(t.agreed_price) AS total_transaction_volume,
    COALESCE(SUM(r.gross_rev), 0) AS gross_revenue,
    COALESCE(SUM(e.total_exp), 0) AS total_expenses,
    COALESCE(SUM(r.gross_rev - e.total_exp), 0) AS net_profit,
    RANK() OVER (ORDER BY COALESCE(SUM(r.gross_rev - e.total_exp), 0) DESC) AS profit_rank
FROM agents a
JOIN offices o ON a.office_id = o.office_id
JOIN transactions t ON a.agent_id = t.closing_agent_id AND t.status = 'Closed'
LEFT JOIN rev_cte r ON t.transaction_id = r.transaction_id
LEFT JOIN exp_cte e ON t.transaction_id = e.transaction_id
GROUP BY a.agent_id, a.first_name, a.last_name, o.office_name
ORDER BY profit_rank;

-- PROCEDURE 2: Buyer Contribution & CLV Quartile Segmentation
WITH client_profit AS (
    SELECT 
        c.client_id,
        c.first_name || ' ' || c.last_name AS client_name,
        COUNT(t.transaction_id) AS total_deals,
        COALESCE(SUM(r.amount - e.tot_exp), 0) AS net_contribution
    FROM clients c
    JOIN transactions t ON c.client_id = t.buyer_client_id
    JOIN revenues r ON t.transaction_id = r.transaction_id
    JOIN (SELECT transaction_id, SUM(amount) AS tot_exp FROM expenses GROUP BY transaction_id) e ON t.transaction_id = e.transaction_id
    GROUP BY c.client_id, c.first_name, c.last_name
    HAVING COUNT(t.transaction_id) >= 1
)
SELECT 
    client_name,
    total_deals,
    net_contribution,
    NTILE(4) OVER (ORDER BY net_contribution DESC) AS clv_quartile
FROM client_profit
ORDER BY clv_quartile, net_contribution DESC;

-- PROCEDURE 3: Regional Office MoM Revenue Growth
WITH monthly_office_rev AS (
    SELECT 
        o.office_name,
        TO_CHAR(t.closing_date, 'YYYY-MM') AS tx_month,
        SUM(r.amount) AS monthly_rev
    FROM offices o
    JOIN agents a ON o.office_id = a.office_id
    JOIN transactions t ON a.agent_id = t.closing_agent_id AND t.status = 'Closed'
    JOIN revenues r ON t.transaction_id = r.transaction_id
    GROUP BY o.office_name, TO_CHAR(t.closing_date, 'YYYY-MM')
)
SELECT 
    office_name,
    tx_month,
    monthly_rev,
    LAG(monthly_rev, 1) OVER (PARTITION BY office_name ORDER BY tx_month) AS prev_month_rev,
    ROUND(((monthly_rev - LAG(monthly_rev, 1) OVER (PARTITION BY office_name ORDER BY tx_month)) / NULLIF(LAG(monthly_rev, 1) OVER (PARTITION BY office_name ORDER BY tx_month), 0)) * 100, 2) AS mom_growth_pct
FROM monthly_office_rev
ORDER BY office_name, tx_month;

-- PROCEDURE 4: Market Price/Sqft Benchmark by Neighborhood
SELECT 
    n.neighborhood_name,
    c.city_name,
    COUNT(t.transaction_id) AS closed_deals,
    ROUND(AVG(t.agreed_price / NULLIF(p.sqft, 0)), 2) AS avg_price_per_sqft
FROM properties p
JOIN neighborhoods n ON p.neighborhood_id = n.neighborhood_id
JOIN cities c ON n.city_id = c.city_id
JOIN listings l ON p.property_id = l.property_id
JOIN transactions t ON l.listing_id = t.listing_id
WHERE t.status = 'Closed'
GROUP BY n.neighborhood_name, c.city_name
ORDER BY avg_price_per_sqft DESC;

-- PROCEDURE 5: Listing Conversion Funnel Rate
SELECT 
    st.service_name,
    COUNT(l.listing_id) AS total_listings,
    COUNT(CASE WHEN l.status IN ('Sold', 'Rented') THEN 1 END) AS converted_listings,
    ROUND((COUNT(CASE WHEN l.status IN ('Sold', 'Rented') THEN 1 END)::numeric / COUNT(l.listing_id)) * 100, 2) AS conversion_rate_pct
FROM listings l
JOIN service_types st ON l.service_type_id = st.service_type_id
GROUP BY st.service_name
ORDER BY conversion_rate_pct DESC;

-- PROCEDURE 6: School Quality Proximity Price Benchmark
SELECT 
    CASE WHEN sch.rating >= 9.0 THEN 'A+ Tier (Rating 9.0-10.0)' ELSE 'Standard Tier (Rating < 9.0)' END AS school_tier,
    COUNT(DISTINCT p.property_id) AS property_count,
    ROUND(AVG(t.agreed_price / NULLIF(p.sqft, 0)), 2) AS avg_agreed_ppsf,
    ROUND(AVG(t.agreed_price), 2) AS avg_agreed_price
FROM properties p
JOIN property_school_proximity psp ON p.property_id = psp.property_id
JOIN schools sch ON psp.school_id = sch.school_id
JOIN listings l ON p.property_id = l.property_id
JOIN transactions t ON l.listing_id = t.listing_id
WHERE t.status = 'Closed'
GROUP BY CASE WHEN sch.rating >= 9.0 THEN 'A+ Tier (Rating 9.0-10.0)' ELSE 'Standard Tier (Rating < 9.0)' END
ORDER BY avg_agreed_ppsf DESC;

-- PROCEDURE 7: Client Cross-Selling Opportunities
SELECT 
    c.client_id,
    c.first_name || ' ' || c.last_name AS client_name,
    c.email,
    COUNT(DISTINCT l.service_type_id) AS services_used
FROM clients c
JOIN listings l ON c.client_id = l.seller_client_id
GROUP BY c.client_id, c.first_name, c.last_name, c.email
HAVING COUNT(DISTINCT l.service_type_id) = 1
ORDER BY c.client_id;

-- PROCEDURE 8: Open House Turnout & Days to Close Analysis
SELECT 
    CASE 
        WHEN oh.attendees_count >= 15 THEN 'High Turnout (15+ Attendees)'
        WHEN oh.attendees_count >= 8 THEN 'Moderate Turnout (8-14 Attendees)'
        ELSE 'Standard Turnout (<8 Attendees)'
    END AS turnout_tier,
    COUNT(t.transaction_id) AS closed_deals,
    ROUND(AVG(t.closing_date - l.list_date), 1) AS avg_days_to_close,
    ROUND(AVG(t.agreed_price / NULLIF(l.asking_price, 0)) * 100, 2) AS price_to_ask_ratio_pct
FROM listings l
JOIN open_houses oh ON l.listing_id = oh.listing_id
JOIN transactions t ON l.listing_id = t.listing_id
WHERE t.status = 'Closed'
GROUP BY 
    CASE 
        WHEN oh.attendees_count >= 15 THEN 'High Turnout (15+ Attendees)'
        WHEN oh.attendees_count >= 8 THEN 'Moderate Turnout (8-14 Attendees)'
        ELSE 'Standard Turnout (<8 Attendees)'
    END
ORDER BY avg_days_to_close ASC;

-- PROCEDURE 9: Operational Expense Category Breakdown
SELECT 
    ec.category_name,
    SUM(e.amount) AS total_spent,
    ROUND((SUM(e.amount) / (SELECT SUM(amount) FROM expenses)) * 100, 2) AS pct_of_total_expenses
FROM expenses e
JOIN expense_categories ec ON e.category_id = ec.category_id
GROUP BY ec.category_name
ORDER BY total_spent DESC;

-- PROCEDURE 10: Tri-State Market Comparison Dashboard
WITH state_tx AS (
    SELECT 
        st.state_id,
        COUNT(DISTINCT t.transaction_id) AS closed_deals,
        SUM(t.agreed_price) AS total_vol
    FROM states st
    JOIN cities ci ON st.state_id = ci.state_id
    JOIN offices o ON ci.city_id = o.city_id
    JOIN agents a ON o.office_id = a.office_id
    JOIN transactions t ON a.agent_id = t.closing_agent_id AND t.status = 'Closed'
    GROUP BY st.state_id
),
state_rev AS (
    SELECT 
        st.state_id, 
        SUM(r.amount) AS total_rev
    FROM states st
    JOIN cities ci ON st.state_id = ci.state_id
    JOIN offices o ON ci.city_id = o.city_id
    JOIN agents a ON o.office_id = a.office_id
    JOIN transactions t ON a.agent_id = t.closing_agent_id AND t.status = 'Closed'
    JOIN revenues r ON t.transaction_id = r.transaction_id
    GROUP BY st.state_id
),
state_exp AS (
    SELECT 
        st.state_id, 
        SUM(e.amount) AS total_exp
    FROM states st
    JOIN cities ci ON st.state_id = ci.state_id
    JOIN offices o ON ci.city_id = o.city_id
    JOIN agents a ON o.office_id = a.office_id
    JOIN transactions t ON a.agent_id = t.closing_agent_id AND t.status = 'Closed'
    JOIN expenses e ON t.transaction_id = e.transaction_id
    GROUP BY st.state_id
)
SELECT 
    st.state_name,
    st.state_abbr,
    COALESCE(stx.closed_deals, 0) AS closed_deals,
    COALESCE(stx.total_vol, 0) AS total_transaction_volume,
    COALESCE(sr.total_rev, 0) AS gross_revenue,
    COALESCE(se.total_exp, 0) AS total_expenses,
    COALESCE(sr.total_rev, 0) - COALESCE(se.total_exp, 0) AS net_profit
FROM states st
LEFT JOIN state_tx stx ON st.state_id = stx.state_id
LEFT JOIN state_rev sr ON st.state_id = sr.state_id
LEFT JOIN state_exp se ON st.state_id = se.state_id
ORDER BY total_transaction_volume DESC;

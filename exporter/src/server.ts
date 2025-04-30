import express from 'express';
import { Octokit } from '@octokit/rest';
import { register, Gauge } from 'prom-client';
import dayjs from 'dayjs';
import 'dotenv/config';

// Environment variables
const app = express();
const port = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
const githubRepo = process.env.GITHUB_REPO;
const token = process.env.GITHUB_TOKEN;

if (!token) {
  throw new Error('Missing GITHUB_TOKEN environment variables');
}

// Octokit instance
const octokit = new Octokit({
  auth: token,
  userAgent: 'github-metrics-exporter',
});

const openPRsGauge = new Gauge({ name: 'github_open_pull_requests_total', help: `Total open PRs in ${githubRepo}` });
const openedPRsTodayGauge = new Gauge({ name: 'github_prs_opened_today', help: `PRs opened today in ${githubRepo}` });
const closedPRsTodayGauge = new Gauge({ name: 'github_prs_closed_today', help: `PRs closed today in ${githubRepo}` });

async function repoCollectMetrics(): Promise<void> {
  try {
    const today = dayjs().format('YYYY-MM-DD');

    console.log(`[DEBUG] Collecting metrics for repo:${githubRepo} (date: ${today})`);

    const openPRs = await octokit.request('GET /search/issues', { q: `repo:${githubRepo} is:pr is:open` });
    const prsOpenedToday = await octokit.request('GET /search/issues', { q: `repo:${githubRepo} is:pr created:${today}` });
    const prsClosedToday = await octokit.request('GET /search/issues', { q: `repo:${githubRepo} is:pr closed:${today}` });

    openPRsGauge.set(openPRs.data.total_count);
    openedPRsTodayGauge.set(prsOpenedToday.data.total_count);
    closedPRsTodayGauge.set(prsClosedToday.data.total_count);

    console.log(`[+] Metrics collected at ${new Date().toISOString()}`);
  } catch (error) {
    console.error('Failed to collect metrics:', error);
  }
}


async function collectMetrics(): Promise<void> {
  // Collect metrics for dummyorg/dummyrepo
  await repoCollectMetrics();

}

// Setup intervals
setInterval(collectMetrics, 3 * 60 * 1000); // every 3 minutes
collectMetrics();

// Metrics endpoint
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Start server
app.listen(port, () => {
  console.log(`GitHub exporter running on port ${port}`);
});

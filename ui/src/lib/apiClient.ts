import type { Client } from '@hey-api/client-fetch';

import type { CreateClientConfig } from '@/client/client.gen';

export const createClientConfig: CreateClientConfig = (config) => {
    // Use different URLs for server-side vs client-side
    const isServer = typeof window === 'undefined';
    let baseUrl: string;

    if (isServer) {
        // for server-side rendering, still use environment variable as fallback
        // `api` hostname only works in Docker networks; localhost works for local uvicorn runs.
        baseUrl = process.env.BACKEND_URL || 'http://localhost:8000';
    } else {
        // Client-side API calls are proxied through Next.js rewrites.
        // AppConfigContext may update this later with the fetched backend URL.
        baseUrl = window.location.origin;
    }

    return {
        ...config,
        baseUrl,
    };
};

let interceptorRegistered = false;

/**
 * Register a request interceptor that attaches a fresh access token
 * to every outgoing SDK request, and a response interceptor that clears
 * the session on 401. Idempotent — safe for React strict mode.
 */
export function setupAuthInterceptor(
    apiClient: Client,
    getAccessToken: () => Promise<string>,
    onUnauthorized: () => void,
) {
    if (interceptorRegistered) return;
    interceptorRegistered = true;

    apiClient.interceptors.request.use(async (request) => {
        if (request.headers.get('Authorization')) {
            return request;
        }
        try {
            const token = await getAccessToken();
            request.headers.set('Authorization', `Bearer ${token}`);
        } catch {
            // If token retrieval fails, let the request proceed without auth
        }
        return request;
    });

    apiClient.interceptors.response.use((response) => {
        if (response.status === 401) {
            onUnauthorized();
        }
        return response;
    });
}

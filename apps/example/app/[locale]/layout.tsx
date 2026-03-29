import type { Metadata } from "next"
import { connection } from "next/server"
import { Fustat, Geist_Mono } from "next/font/google"
import { notFound } from "next/navigation"
import { NextIntlClientProvider } from "next-intl"
import { getMessages, getTranslations } from "next-intl/server"
import type { ReactNode } from "react"

import "@workspace/ui/globals.css"
import { AppProviders } from "@/app/_providers/app-providers"
import { routing } from "@/i18n/routing"
import { getSiteUrl } from "@/lib/site-url"
import { cn } from "@workspace/ui/lib/utils"

const fontSans = Fustat({
  subsets: ["latin", "latin-ext"],
  variable: "--font-sans",
})

const fontMono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-serif",
})

type Props = Readonly<{
  children: ReactNode
  params: Promise<{ locale: string }>
}>

function ensureValidLocale(locale: string): (typeof routing.locales)[number] {
  if (!routing.locales.includes(locale as (typeof routing.locales)[number])) {
    notFound()
  }
  return locale as (typeof routing.locales)[number]
}

function openGraphLocaleTag(locale: string): string {
  if (locale === "pt") {
    return "pt_PT"
  }
  return "en_US"
}

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }))
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale: rawLocale } = await params
  const locale = ensureValidLocale(rawLocale)

  const t = await getTranslations({ locale, namespace: "Metadata" })
  const siteUrl = getSiteUrl()
  const metadataBase = new URL(`${siteUrl}/`)

  const languageAlternates = Object.fromEntries(
    routing.locales.map((l) => {
      const path = l === routing.defaultLocale ? "/" : `/${l}`
      return [l, new URL(path, metadataBase).toString()]
    })
  )

  const canonicalPath = locale === routing.defaultLocale ? "/" : `/${locale}`

  return {
    metadataBase,
    title: {
      default: t("title"),
      template: `%s — ${t("title")}`,
    },
    description: t("description"),
    alternates: {
      canonical: canonicalPath,
      languages: languageAlternates,
    },
    openGraph: {
      type: "website",
      locale: openGraphLocaleTag(locale),
      url: canonicalPath,
      siteName: t("title"),
      title: t("title"),
      description: t("description"),
      images: [
        {
          url: "/og-default.png",
          width: 1200,
          height: 630,
          alt: t("title"),
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: t("title"),
      description: t("description"),
      images: ["/og-default.png"],
    },
  }
}

export default async function LocaleLayout({ children, params }: Props) {
  if (process.env.CSP_ENFORCE === "1") {
    await connection()
  }

  const { locale: rawLocale } = await params
  const locale = ensureValidLocale(rawLocale)

  const messages = await getMessages()

  return (
    <html lang={locale} suppressHydrationWarning>
      <body className={cn("antialiased", fontMono.variable, fontSans.variable)}>
        <NextIntlClientProvider messages={messages}>
          <AppProviders>{children}</AppProviders>
        </NextIntlClientProvider>
      </body>
    </html>
  )
}

# syntax=docker/dockerfile:1.2

ARG BASE_IMAGE=atrawog/jupyter-devel:20231210
FROM --platform=$BUILDPLATFORM $BASE_IMAGE AS fetch
Shader "Custom/RimLight"
{
    Properties
    {
        _BaseMap ("Base Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)

        _NormalMap ("Normal Map", 2D) = "bump" {}

        [HDR] _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimPower ("Rim Power", Range(0.5, 8)) = 4
        _RimMin ("Rim Min", Range(0, 1)) = 0.4
        _RimMax ("Rim Max", Range(0, 1)) = 0.8
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            Name "RimForward"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float3 tangentWS   : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float2 uv          : TEXCOORD4;
            };
            
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;

            float4 _RimColor;
            float _RimPower;
            float _RimMin;
            float _RimMax;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);

                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

                float3 tangentWS = TransformObjectToWorldDir(IN.tangentOS.xyz);
                OUT.bitangentWS = cross(OUT.normalWS, tangentWS) * IN.tangentOS.w;

                OUT.tangentWS = tangentWS;

                OUT.uv = IN.uv;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // -------- Base Texture --------
                float4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                float3 baseColor = baseSample.rgb * _BaseColor.rgb;
                float alpha = baseSample.a * _BaseColor.a;

                // -------- Normal Mapping --------
                float3 normalTS = UnpackNormal(
                    SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv)
                );
                
                float3x3 TBN = float3x3(
                    normalize(IN.tangentWS),
                    normalize(IN.bitangentWS),
                    normalize(IN.normalWS)
                );

                float3 normalWS = normalize(mul(normalTS, TBN));

                // -------- View Direction --------
                float3 viewDirWS = normalize(GetWorldSpaceViewDir(IN.positionWS));
                
                // -------- Rim Light --------
                float3 n = normalize(normalWS);
                float3 v = normalize(viewDirWS);
                float rim = 1 - saturate(dot(n, v));    // Rim factor is normal¡¤view
                rim = smoothstep(_RimMin, _RimMax, rim);    // Control rim thickness
                rim = pow(rim, _RimPower);

                float3 finalColor = baseColor * _RimColor.rgb * rim;
                float finalAlpha = alpha * _RimColor.a * rim;
                return float4(finalColor, finalAlpha);
            }

            ENDHLSL
        }
    }
}

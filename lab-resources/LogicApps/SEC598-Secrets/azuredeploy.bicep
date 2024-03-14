param workflows_SEC598_Secrets_name string = 'SEC598-Secrets'
param workspaces_SEC598_Workspace_name string = 'SEC598-Workspace'
param solutions_SecurityInsights_sec598_workspace_name string = 'SecurityInsights(sec598-workspace)'

resource workflows_SEC598_Secrets_name_resource 'Microsoft.Logic/workflows@2017-07-01' = {
  name: workflows_SEC598_Secrets_name
  location: 'eastus'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        'Mail adres to': {
          defaultValue: 'info@sec598.com'
          type: 'String'
        }
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Microsoft_Sentinel_incident: {
          type: 'ApiConnectionWebhook'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
              }
            }
            body: {
              callback_url: '@{listCallbackUrl()}'
            }
            path: '/incident-creation'
          }
        }
      }
      actions: {
        For_each: {
          foreach: '@triggerBody()?[\'object\']?[\'properties\']?[\'Alerts\']'
          actions: {
            Parse_addeditional_values_in_incident: {
              type: 'ParseJson'
              inputs: {
                content: '@items(\'For_each\')?[\'properties\']?[\'additionalData\']?[\'Custom Details\']'
                schema: {
                  type: 'object'
                  properties: {
                    ApplicationName: {
                      type: 'array'
                      items: {
                        type: 'string'
                      }
                    }
                    TimeGenerated: {
                      type: 'array'
                      items: {
                        type: 'string'
                      }
                    }
                    ActivityDisplayName: {
                      type: 'array'
                      items: {
                        type: 'string'
                      }
                    }
                    Property: {
                      type: 'array'
                      items: {
                        type: 'string'
                      }
                    }
                  }
                }
              }
            }
            Send_approval_Mail_to_Contact_Person_for_change: {
              runAfter: {
                Parse_addeditional_values_in_incident: [
                  'Succeeded'
                ]
              }
              type: 'ApiConnectionWebhook'
              inputs: {
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                body: {
                  NotificationUrl: '@{listCallbackUrl()}'
                  Message: {
                    To: 'jeroen@agron.be'
                    Body: 'You received an approval request for @{body(\'Parse_addeditional_values_in_incident\')?[\'ApplicationName\']} on @{body(\'Parse_addeditional_values_in_incident\')?[\'TimeGenerated\']} \n<br /> \nFull details of the Alert below: \n<br /> \n@{body(\'Parse_addeditional_values_in_incident\')?[\'Property\']}\n<br />'
                    Importance: 'Normal'
                    HideHTMLMessage: false
                    ShowHTMLConfirmationDialog: false
                    Subject: 'Approval Request-@{body(\'Parse_addeditional_values_in_incident\')?[\'ActivityDisplayName\'] } - @{body(\'Parse_addeditional_values_in_incident\')?[\'ApplicationName\']}'
                    Options: 'Approve, Reject'
                  }
                }
                path: '/approvalmail/$subscriptions'
              }
            }
            Condition: {
              actions: {
                'Add_comment_to_incident_(V3)': {
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'azuresentinel\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    body: {
                      incidentArmId: '@triggerBody()?[\'object\']?[\'id\']'
                      message: '<p>The application @{body(\'Parse_addeditional_values_in_incident\')?[\'ApplicationName\']} is approved!</p>'
                    }
                    path: '/Incidents/Comment'
                  }
                }
              }
              runAfter: {
                Send_approval_Mail_to_Contact_Person_for_change: [
                  'Succeeded'
                ]
              }
              else: {
                actions: {
                  'Send_an_email_(V2)': {
                    type: 'ApiConnection'
                    inputs: {
                      host: {
                        connection: {
                          name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                        }
                      }
                      method: 'post'
                      body: {
                        To: 'info@sec598.com'
                        Subject: 'Application Update - Rejected'
                        Body: '<p>Request for @{body(\'Parse_addeditional_values_in_incident\')?[\'ApplicationName\'] } is Rejected!</p>'
                        Importance: 'Normal'
                      }
                      path: '/v2/Mail'
                    }
                  }
                }
              }
              expression: {
                and: [
                  {
                    equals: [
                      '@body(\'Send_approval_Mail_to_Contact_Person_for_change\')?[\'SelectedOption\']'
                      'Approve'
                    ]
                  }
                ]
              }
              type: 'If'
            }
          }
          runAfter: {}
          type: 'Foreach'
        }
      }
      outputs: {}
    }
    parameters: {}
  }
}

resource workspaces_SEC598_Workspace_name_resource 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: workspaces_SEC598_Workspace_name
  location: 'eastus'
  tags: {
    SANS: 'SEC598'
  }
  properties: {
    sku: {
      name: 'pergb2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource solutions_SecurityInsights_sec598_workspace_name_resource 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: solutions_SecurityInsights_sec598_workspace_name
  location: 'eastus'
  plan: {
    name: 'SecurityInsights(sec598-workspace)'
    promotionCode: ''
    product: 'OMSGallery/SecurityInsights'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: workspaces_SEC598_Workspace_name_resource.id
    containedResources: []
  }
}